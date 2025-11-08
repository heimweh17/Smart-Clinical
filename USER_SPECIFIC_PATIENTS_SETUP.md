# User-Specific Patient Access Setup Guide

This guide explains how to set up user-specific patient access so each doctor only sees their own patients, plus how to use the "Add Patient" feature.

## What's Been Implemented

### 1. User-Specific Patient Access
- Each patient is linked to a specific doctor/user account
- Doctors can only see, edit, and delete their own patients
- Implemented using Row Level Security (RLS) in Supabase

### 2. Add Patient Feature
- Green "Add Patient" button in the dashboard header
- Beautiful modal popup overlay with form
- Auto-generates unique 6-digit MRN numbers
- Automatically links patient to logged-in doctor
- Fields: Patient Name, Date of Birth, Visit Date & Time

---

## Step-by-Step Setup Instructions

### Step 1: Run the SQL Setup

Go to **Supabase Dashboard > SQL Editor** and run this SQL:

```sql
-- Step 1: Add user_id column to patients table
ALTER TABLE patients ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Create index for faster queries
CREATE INDEX idx_patients_user_id ON patients(user_id);

-- Step 3: Drop existing RLS policies (if any)
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

-- Step 5: Create a function to auto-generate MRN (optional - the app does this in JavaScript)
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
```

**Note:** A ready-to-use SQL file has been created at: [supabase_user_specific_setup.sql](supabase_user_specific_setup.sql)

### Step 2: Update Existing Patient Data (Optional)

If you have existing patients in the database without a `user_id`, you need to assign them to a user:

```sql
-- Option A: Assign all existing patients to a specific user
UPDATE patients
SET user_id = 'YOUR-USER-ID-HERE'
WHERE user_id IS NULL;

-- To find your user ID, run:
SELECT id, email FROM auth.users;
```

**OR delete all existing test data:**

```sql
-- Option B: Delete all existing patients (if they're just test data)
DELETE FROM patients;
```

---

## How to Use the Add Patient Feature

### For End Users (Doctors)

1. **Log in** to your account
2. Click the **"Add Patient"** button (green button with + icon) in the top right
3. Fill in the form:
   - **Patient Name**: Full name of the patient
   - **Date of Birth**: Select from calendar
   - **Visit Date & Time**: Defaults to current time, but can be changed
4. Click **"Add Patient"**
5. The MRN is automatically generated and displayed
6. The patient appears in your list immediately

### Features:
- ✅ Auto-fills visit date/time with current date/time
- ✅ Auto-generates unique 6-digit MRN
- ✅ Validates all required fields
- ✅ Shows success message with assigned MRN
- ✅ Closes modal and refreshes patient list automatically
- ✅ Can click outside modal or press Cancel/X to close

---

## How Patient Isolation Works

### Database Level
- Each patient has a `user_id` column that references the user who created them
- Row Level Security (RLS) policies enforce access control
- Supabase automatically filters queries to only return patients where `user_id` matches the logged-in user

### Code Level
```javascript
// When fetching patients
const { data: patients } = await supabase
  .from('patients')
  .select('*')
  .eq('user_id', user.id)  // ← Only gets current user's patients
  .order('visit_date', { ascending: true });

// When adding patients
await supabase
  .from('patients')
  .insert([{
    patient_name: name,
    date_of_birth: dob,
    mrn: mrn,
    visit_date: visitDate,
    user_id: user.id  // ← Automatically links to current user
  }]);
```

---

## File Changes Made

### Modified Files:

1. **dashboard_screen/dashboard.html**
   - Added "Add Patient" button (line 33-40)
   - Added modal overlay HTML (line 65-104)
   - Added modal functionality JavaScript (line 343-470)
   - Updated loadPatients() to filter by user_id (line 184-195)
   - Added patient creation form handler (line 389-469)

2. **dashboard_screen/style.css**
   - Added button styling (line 321-354)
   - Added modal overlay styling (line 356-581)
   - Added responsive modal styles (line 548-581)

### New Files:

1. **supabase_user_specific_setup.sql**
   - Complete SQL setup for user-specific access
   - Auto-MRN generation function
   - RLS policies

2. **USER_SPECIFIC_PATIENTS_SETUP.md**
   - This documentation file

---

## Testing Your Setup

### Test 1: User Isolation

1. Create two different user accounts (use signup.html)
2. Log in with User A
3. Add a patient (e.g., "John Doe")
4. Log out
5. Log in with User B
6. You should NOT see "John Doe" in the patient list
7. Add a different patient (e.g., "Jane Smith")
8. Log out
9. Log in with User A again
10. You should ONLY see "John Doe", not "Jane Smith"

### Test 2: Add Patient Feature

1. Log in to your account
2. Click "Add Patient" button
3. Fill in all fields
4. Click "Add Patient"
5. Verify you see success message with MRN
6. Verify patient appears in the list
7. Refresh the page
8. Verify patient is still there

### Test 3: MRN Generation

1. Add multiple patients quickly
2. Check that all MRNs are unique
3. MRNs should be 6-digit numbers (100000-999999)

---

## Troubleshooting

### Issue: "Error loading patients" on dashboard

**Causes:**
- RLS policies not set up
- user_id column doesn't exist
- User not logged in

**Solutions:**
1. Run the SQL setup from Step 1
2. Check browser console for error details
3. Verify you're logged in (check that user info shows in header)

### Issue: Can't add patients - "Failed to add patient"

**Causes:**
- RLS policies preventing insert
- Missing user_id in insert
- Database connection issues

**Solutions:**
1. Check browser console for detailed error
2. Verify RLS policies allow INSERT for authenticated users
3. Make sure you're logged in

### Issue: See patients from other users

**Causes:**
- RLS policies not properly configured
- Using old policy that shows all patients

**Solutions:**
1. Drop ALL existing policies
2. Re-run Step 4 from the SQL setup
3. Verify policies with: `SELECT * FROM pg_policies WHERE tablename = 'patients';`

### Issue: MRN already exists error

**Very rare** - happens if random number collision occurs twice

**Solution:**
- The code automatically retries with a new MRN
- If it persists, check that MRNs are being stored correctly (as integers or text)

---

## Security Considerations

### ✅ What's Secure:

1. **Row Level Security (RLS)** prevents users from accessing others' patients
2. **User ID validation** ensures patients are linked to correct user
3. **Automatic filtering** at database level prevents data leaks
4. **MRN uniqueness** is checked before insertion

### ⚠️ Best Practices:

1. **Never disable RLS** on the patients table
2. **Keep Supabase anon key public** (it's safe, RLS protects the data)
3. **Never expose service_role key** in client-side code
4. **Validate input** on both client and server side
5. **Use HTTPS only** in production

---

## Future Enhancements

Potential features to add:

1. **Edit Patient**: Click patient card to edit details
2. **Delete Patient**: Add delete button with confirmation
3. **Patient Search**: Already implemented! Use search box
4. **Bulk Import**: CSV upload for multiple patients
5. **Patient Notes**: Add notes/comments per patient
6. **Appointment Scheduling**: Link to calendar
7. **Export to PDF**: Generate patient reports
8. **Patient Photos**: Upload profile pictures

---

## Summary

You now have:

✅ User-specific patient access (each doctor sees only their patients)
✅ Add Patient button with beautiful modal popup
✅ Auto-generated unique MRN numbers
✅ Real-time patient list updates
✅ Secure Row Level Security policies
✅ Responsive design for mobile and desktop

## Next Steps

1. Run the SQL in Supabase
2. Refresh your dashboard
3. Try adding a patient
4. Test with multiple user accounts
5. Customize the fields or styling as needed

---

## Support

If you encounter any issues:

1. Check browser console (F12 > Console tab)
2. Check Supabase logs (Dashboard > Logs)
3. Verify RLS policies are active
4. Make sure you're logged in
5. Check that your table structure matches the schema
