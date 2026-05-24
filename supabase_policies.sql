-- ====================================================
-- 1. Helper Functions to replicate Firebase Rules
-- ====================================================

-- Check if user is Super Admin by email
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN COALESCE(auth.jwt() ->> 'email', '') IN (
    'muhammadbindaddy@gmail.com', 
    'devmuhamammadalbani@gmail.com',
    'yarmamaihsan@gmail.com'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Toggle user active status in a single round-trip (no read needed) ──────
-- Run this in Supabase SQL Editor once.
CREATE OR REPLACE FUNCTION toggle_user_active(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users SET is_active = NOT is_active WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user has a specific role (and is active) OR is Super Admin
CREATE OR REPLACE FUNCTION has_role(role_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Super Admins automatically bypass all role checks
  IF is_super_admin() THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() 
      AND role = role_name 
      AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ====================================================
-- 2. Clean up existing policies to avoid duplicates
-- ====================================================
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON ' || quote_ident(r.tablename);
    END LOOP;
END $$;


-- ====================================================
-- 3. Enable RLS on all tables
-- ====================================================
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE imaging_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- If audit_logs table exists
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID,
    user_name TEXT,
    user_role TEXT,
    ward TEXT,
    action TEXT,
    resource_type TEXT,
    resource_id TEXT,
    details TEXT,
    severity TEXT DEFAULT 'INFO',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;


-- ====================================================
-- 4. Create Policies (Matching Firestore Rules)
-- ====================================================

-- --- GLOBAL READ FOR INFRASTRUCTURE ---
CREATE POLICY "Allow authenticated read departments" ON departments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read rooms" ON rooms FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read tariffs" ON tariffs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read settings" ON settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read appointments" ON appointments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read admissions" ON admissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read patients" ON patients FOR SELECT TO authenticated USING (true);


-- --- DEPARTMENTS, ROOMS, TARIFFS, SETTINGS WRITES ---
CREATE POLICY "Allow Admin to write departments" ON departments
    FOR ALL TO authenticated USING (has_role('Admin'));

CREATE POLICY "Allow Admin/Biller/Nurse to write rooms" ON rooms
    FOR ALL TO authenticated USING (has_role('Admin') OR has_role('Biller') OR has_role('Nurse'));

CREATE POLICY "Allow Admin to write tariffs" ON tariffs
    FOR ALL TO authenticated USING (has_role('Admin'));

CREATE POLICY "Allow Admin to write settings" ON settings
    FOR ALL TO authenticated USING (has_role('Admin'));


-- --- USERS (Staff Profiles) ---
-- Allow authenticated users to read all staff profiles
CREATE POLICY "Allow authenticated read users" ON users
    FOR SELECT TO authenticated USING (true);

-- Allow anon (unauthenticated) role to read users table.
-- IMPORTANT: Required so that the login flow can verify staff existence
-- before a Supabase Auth session is established.
CREATE POLICY "Allow anon read users for login" ON users
    FOR SELECT TO anon USING (true);

CREATE POLICY "Allow write users if self or Admin" ON users
    FOR ALL TO authenticated USING (
        is_super_admin() 
        OR auth.uid() = id 
        OR COALESCE(auth.jwt() ->> 'email', '') = email
        OR has_role('Admin')
    );


-- --- PATIENTS ---
CREATE POLICY "Allow staff to write patients" ON patients
    FOR ALL TO authenticated USING (
        has_role('Admin') OR has_role('Receptionist') OR has_role('Nurse') OR has_role('Doctor')
    );


-- --- APPOINTMENTS ---
CREATE POLICY "Allow staff to create appointments" ON appointments
    FOR INSERT TO authenticated WITH CHECK (
        has_role('Admin') OR has_role('Receptionist') OR has_role('Doctor') OR has_role('Biller')
    );

CREATE POLICY "Allow staff to update appointments" ON appointments
    FOR UPDATE TO authenticated USING (
        has_role('Admin') OR has_role('Receptionist') OR has_role('Doctor') OR has_role('Biller') OR 
        (
            has_role('Nurse') AND 
            NEW.status <> 'AwaitingConsultation' AND 
            NEW.doctor_id IS NOT DISTINCT FROM OLD.doctor_id AND 
            NEW.doctor_name IS NOT DISTINCT FROM OLD.doctor_name
        )
    );

CREATE POLICY "Allow Admin to delete appointments" ON appointments
    FOR DELETE TO authenticated USING (has_role('Admin'));


-- --- CLINICAL RECORDS (Clinical Notes, Progress Notes, Orders, Prescriptions) ---
-- Clinical Notes
CREATE POLICY "Allow clinical read clinical_notes" ON clinical_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow clinical staff to create clinical_notes" ON clinical_notes
    FOR INSERT TO authenticated WITH CHECK (
        (has_role('Admin') OR has_role('Doctor') OR has_role('Nurse')) AND 
        NEW.patient_id IS NOT NULL AND NEW.notes IS NOT NULL
    );
CREATE POLICY "Allow Admin to modify clinical_notes" ON clinical_notes
    FOR UPDATE, DELETE TO authenticated USING (has_role('Admin'));

-- Progress Notes
CREATE POLICY "Allow clinical read progress_notes" ON progress_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow clinical staff to create progress_notes" ON progress_notes
    FOR INSERT TO authenticated WITH CHECK (
        (has_role('Admin') OR has_role('Doctor') OR has_role('Nurse')) AND 
        NEW.patient_id IS NOT NULL AND NEW.notes IS NOT NULL
    );
CREATE POLICY "Allow Admin to modify progress_notes" ON progress_notes
    FOR UPDATE, DELETE TO authenticated USING (has_role('Admin'));

-- Lab Orders
CREATE POLICY "Allow staff read lab_orders" ON lab_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow staff to write lab_orders" ON lab_orders
    FOR ALL TO authenticated USING (
        has_role('Admin') OR has_role('Doctor') OR has_role('Laboratory') OR has_role('Biller')
    );

-- Prescriptions
CREATE POLICY "Allow staff read prescriptions" ON prescriptions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow staff to write prescriptions" ON prescriptions
    FOR ALL TO authenticated USING (
        has_role('Admin') OR has_role('Doctor') OR has_role('Pharmacist') OR has_role('Biller')
    );

-- Imaging Orders
CREATE POLICY "Allow staff read imaging_orders" ON imaging_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow staff to write imaging_orders" ON imaging_orders
    FOR ALL TO authenticated USING (
        has_role('Admin') OR has_role('Doctor') OR has_role('Radiology') OR has_role('Biller')
    );


-- --- INVENTORY ---
CREATE POLICY "Allow staff read pharmacy_inventory" ON pharmacy_inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow staff to write pharmacy_inventory" ON pharmacy_inventory
    FOR ALL TO authenticated USING (
        has_role('Admin') OR has_role('Pharmacist')
    );


-- --- ADMISSIONS ---
CREATE POLICY "Allow staff to create admissions" ON admissions
    FOR INSERT TO authenticated WITH CHECK (
        has_role('Admin') OR has_role('Doctor')
    );

CREATE POLICY "Allow staff to update admissions" ON admissions
    FOR UPDATE TO authenticated USING (
        has_role('Admin') OR has_role('Doctor') OR has_role('Biller') OR 
        (
            has_role('Nurse') AND 
            (
                SELECT specialty FROM public.users WHERE id = auth.uid()
            ) IN (OLD.room_id::TEXT, OLD.room_name)
        )
    );

CREATE POLICY "Allow Admin to delete admissions" ON admissions
    FOR DELETE TO authenticated USING (has_role('Admin'));


-- --- BILLING & EXPENSES ---
CREATE POLICY "Allow authenticated read billing" ON billing FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow staff to create billing" ON billing
    FOR INSERT TO authenticated WITH CHECK (
        has_role('Admin') OR has_role('Biller') OR has_role('Pharmacist')
    );
CREATE POLICY "Allow financial staff to update billing" ON billing
    FOR UPDATE, DELETE TO authenticated USING (
        has_role('Admin') OR has_role('Biller')
    );

-- Expenses
CREATE POLICY "Allow financial staff read expenses" ON expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow financial staff to write expenses" ON expenses
    FOR ALL TO authenticated USING (
        has_role('Admin') OR has_role('Biller')
    );


-- --- NOTIFICATIONS ---
CREATE POLICY "Allow authenticated to manage notifications" ON notifications
    FOR ALL TO authenticated USING (true);


-- --- AUDIT LOGS ---
CREATE POLICY "Allow Admin to view audit_logs" ON audit_logs
    FOR SELECT TO authenticated USING (has_role('Admin'));

CREATE POLICY "Allow authenticated to create audit_logs" ON audit_logs
    FOR INSERT TO authenticated WITH CHECK (true);
