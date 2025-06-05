/*
  # Initial Schema Setup for Preplaced Clone

  1. New Tables
    - `profiles`
      - `id` (uuid, primary key) - References auth.users
      - `full_name` (text) - User's full name
      - `avatar_url` (text) - URL to user's avatar
      - `created_at` (timestamp) - When the profile was created
      - `updated_at` (timestamp) - When the profile was last updated
    
    - `mentors`
      - `id` (uuid, primary key) - References profiles
      - `company` (text) - Current company
      - `position` (text) - Current position
      - `experience_years` (int) - Years of experience
      - `hourly_rate` (int) - Hourly rate in USD
      - `bio` (text) - Mentor's bio
      - `expertise` (text[]) - Array of expertise areas
      - `available` (boolean) - Whether mentor is currently available
    
    - `bookings`
      - `id` (uuid, primary key)
      - `mentor_id` (uuid) - References mentors
      - `user_id` (uuid) - References profiles
      - `start_time` (timestamptz) - Session start time
      - `duration` (int) - Duration in minutes
      - `status` (text) - Booking status (pending/confirmed/completed/cancelled)
      - `created_at` (timestamp) - When the booking was created
      - `updated_at` (timestamp) - When the booking was last updated

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create profiles table
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Create mentors table
CREATE TABLE mentors (
  id uuid PRIMARY KEY REFERENCES profiles ON DELETE CASCADE,
  company text NOT NULL,
  position text NOT NULL,
  experience_years int NOT NULL,
  hourly_rate int NOT NULL,
  bio text NOT NULL,
  expertise text[] NOT NULL,
  available boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE mentors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view available mentors"
  ON mentors FOR SELECT
  TO authenticated
  USING (available = true);

CREATE POLICY "Mentors can update own profile"
  ON mentors FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Create bookings table
CREATE TABLE bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid REFERENCES mentors ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES profiles ON DELETE CASCADE NOT NULL,
  start_time timestamptz NOT NULL,
  duration int NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled'))
);

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookings"
  ON bookings FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = mentor_id);

CREATE POLICY "Users can create bookings"
  ON bookings FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bookings"
  ON bookings FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = mentor_id)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = mentor_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mentors_updated_at
  BEFORE UPDATE ON mentors
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();