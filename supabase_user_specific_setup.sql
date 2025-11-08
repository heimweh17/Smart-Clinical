-- Step 1: Add user_id column to patients table
ALTER TABLE patients ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Create index for faster queries
CREATE INDEX idx_patients_user_id ON patients(user_id);

-- Step 3: Drop existing RLS policies
DROP POLICY IF EXISTS "Allow authenticated users to read patients" ON patients;
DROP POLICY IF EXISTS "Allow authenticated users to insert patients" ON patients;
DROP POLICY IF EXISTS "Allow authenticated users to update patients" ON patients;
DROP POLICY IF EXISTS "Allow authenticated users to delete patients" ON patients;

-- Step 4: Create user-specific RLS policies
-- Users can only read their own patients
CREATE POLICY "Users can read own patients"
  ON patients
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert patients for themselves
CREATE POLICY "Users can insert own patients"
  ON patients
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own patients
CREATE POLICY "Users can update own patients"
  ON patients
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own patients
CREATE POLICY "Users can delete own patients"
  ON patients
  FOR DELETE
  USING (auth.uid() = user_id);

-- Step 5: Create a function to auto-generate MRN
-- This generates a random 6-digit MRN
CREATE OR REPLACE FUNCTION generate_mrn()
RETURNS TEXT AS $$
DECLARE
  new_mrn TEXT;
  mrn_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate a random 6-digit number
    new_mrn := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

    -- Check if this MRN already exists
    SELECT EXISTS(SELECT 1 FROM patients WHERE mrn::TEXT = new_mrn) INTO mrn_exists;

    -- If it doesn't exist, we can use it
    IF NOT mrn_exists THEN
      RETURN new_mrn;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Note: If you want sequential MRNs instead, use this alternative function:
-- CREATE OR REPLACE FUNCTION generate_mrn()
-- RETURNS TEXT AS $$
-- DECLARE
--   max_mrn INTEGER;
-- BEGIN
--   SELECT COALESCE(MAX(mrn::INTEGER), 100000) INTO max_mrn FROM patients;
--   RETURN (max_mrn + 1)::TEXT;
-- END;
-- $$ LANGUAGE plpgsql;
