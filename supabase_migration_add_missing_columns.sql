-- ================================================================
-- SAHARA EHR — COMPLETE DATABASE SETUP
-- Copy ALL of this and run it in Supabase SQL Editor.
-- This drops and recreates everything cleanly.
-- WARNING: This will DELETE all existing data.
-- ================================================================


-- ── STEP 1: DROP ALL EXISTING TABLES (clean slate) ──────────────
DROP TABLE IF EXISTS audit_logs          CASCADE;
DROP TABLE IF EXISTS notifications       CASCADE;
DROP TABLE IF EXISTS expenses            CASCADE;
DROP TABLE IF EXISTS billing             CASCADE;
DROP TABLE IF EXISTS admissions          CASCADE;
DROP TABLE IF EXISTS prescriptions       CASCADE;
DROP TABLE IF EXISTS imaging_orders      CASCADE;
DROP TABLE IF EXISTS lab_orders          CASCADE;
DROP TABLE IF EXISTS progress_notes      CASCADE;
DROP TABLE IF EXISTS clinical_notes      CASCADE;
DROP TABLE IF EXISTS appointments        CASCADE;
DROP TABLE IF EXISTS pharmacy_inventory  CASCADE;
DROP TABLE IF EXISTS tariffs             CASCADE;
DROP TABLE IF EXISTS rooms               CASCADE;
DROP TABLE IF EXISTS departments         CASCADE;
DROP TABLE IF EXISTS patients            CASCADE;
DROP TABLE IF EXISTS settings            CASCADE;
DROP TABLE IF EXISTS users               CASCADE;


-- ── STEP 2: DROP HELPER FUNCTIONS (recreate cleanly) ────────────
DROP FUNCTION IF EXISTS is_super_admin()      CASCADE;
DROP FUNCTION IF EXISTS has_role(TEXT)        CASCADE;
DROP FUNCTION IF EXISTS toggle_user_active(UUID) CASCADE;
DROP FUNCTION IF EXISTS auto_confirm_user()   CASCADE;


-- ── STEP 3: EXTENSIONS ──────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ── STEP 4: HELPER FUNCTIONS ────────────────────────────────────

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

CREATE OR REPLACE FUNCTION has_role(role_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF is_super_admin() THEN RETURN TRUE; END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = role_name AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION toggle_user_active(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users SET is_active = NOT is_active WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-confirm new signups (bypass email verification)
CREATE OR REPLACE FUNCTION public.auto_confirm_user()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email_confirmed_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_user();

-- Auto-confirm all currently unconfirmed users
UPDATE auth.users SET email_confirmed_at = NOW() WHERE email_confirmed_at IS NULL;


-- ── STEP 5: CREATE ALL TABLES ────────────────────────────────────

-- SETTINGS
CREATE TABLE settings (
    setting_key   TEXT PRIMARY KEY,
    setting_value JSONB,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- USERS (Staff Profiles)
CREATE TABLE users (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                   TEXT UNIQUE NOT NULL,
    username                TEXT,
    password                TEXT,
    name                    TEXT NOT NULL,
    role                    TEXT NOT NULL,
    specialty               TEXT,
    is_active               BOOLEAN DEFAULT FALSE,
    linked_uid              UUID,
    last_verified_at        TIMESTAMPTZ,
    is_online               BOOLEAN DEFAULT FALSE,
    last_seen               TIMESTAMPTZ,
    admin_verification_code TEXT,
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

-- PATIENTS
CREATE TABLE patients (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id                  TEXT UNIQUE NOT NULL,
    name                        TEXT NOT NULL,
    surname                     TEXT,
    first_name                  TEXT,
    other_names                 TEXT,
    dob                         DATE,
    age                         INT,
    gender                      TEXT,
    marital_status              TEXT,
    occupation                  TEXT,
    phone_primary               TEXT UNIQUE,        -- nullable: saved as NULL if not provided
    phone_secondary             TEXT,
    email                       TEXT,
    address                     TEXT,
    state                       TEXT,
    lga                         TEXT,
    nok_full_name               TEXT,
    nok_relationship            TEXT,
    nok_phone                   TEXT,
    nok_address                 TEXT,
    payment_type                TEXT DEFAULT 'Cash',
    hmo_provider                TEXT,
    hmo_id                      TEXT,
    auth_code                   TEXT,
    coverage_details            TEXT,
    emergency_contact_same_as_nok BOOLEAN DEFAULT TRUE,
    emergency_name              TEXT,
    emergency_phone             TEXT,
    emergency_address           TEXT,
    photo                       TEXT,
    registered_by               TEXT,
    status                      TEXT DEFAULT 'Active',
    registered_at               TIMESTAMPTZ DEFAULT NOW(),
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);

-- DEPARTMENTS
CREATE TABLE departments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ROOMS
CREATE TABLE rooms (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,
    capacity      INT DEFAULT 0,       -- used by frontend as total beds
    total_beds    INT DEFAULT 0,
    occupied_beds INT DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- TARIFFS
CREATE TABLE tariffs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT UNIQUE NOT NULL,
    amount     NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- APPOINTMENTS
CREATE TABLE appointments (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id       UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name     TEXT,
    doctor_id        UUID,
    doctor_name      TEXT,
    status           TEXT DEFAULT 'PendingBilling',
    billing_status   TEXT DEFAULT 'Unpaid',
    appointment_fee  NUMERIC DEFAULT 0,
    vitals           JSONB,
    ward             TEXT,
    ward_id          TEXT,
    condition        TEXT,
    authorized_by    TEXT,
    payment_method   TEXT,
    auth_code        TEXT,
    date             TEXT,
    time             TEXT,
    reason           TEXT,
    priority         TEXT DEFAULT 'Normal',
    scheduled_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- CLINICAL NOTES
CREATE TABLE clinical_notes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name    TEXT,
    doctor_id       UUID,
    doctor_name     TEXT,
    provider        TEXT,
    role            TEXT,
    type            TEXT,
    template_name   TEXT,
    notes           TEXT,
    content         JSONB,
    diagnosis       TEXT,
    symptoms        TEXT,
    treatment_plan  TEXT,
    is_confidential BOOLEAN DEFAULT TRUE,
    signature       TEXT,
    signed_at       TIMESTAMPTZ,
    lab_order_id    UUID,
    appointment_id  UUID,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- PROGRESS NOTES
CREATE TABLE progress_notes (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name   TEXT,
    author_id      UUID,
    author_name    TEXT,
    author_role    TEXT,
    provider       TEXT,
    role           TEXT,
    type           TEXT,
    notes          TEXT,
    text           TEXT,
    appointment_id UUID,
    timestamp      BIGINT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- LAB ORDERS
CREATE TABLE lab_orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name    TEXT,
    doctor_id       UUID,
    doctor_name     TEXT,
    lab_tests       TEXT,
    status          TEXT DEFAULT 'PendingBilling',
    billing_status  TEXT DEFAULT 'Unpaid',
    reviewed        BOOLEAN DEFAULT FALSE,
    results         TEXT,
    authorized_by   TEXT,
    payment_method  TEXT,
    auth_code       TEXT,
    completed_by    TEXT,
    completed_at    TIMESTAMPTZ,
    ward            TEXT,
    priority        TEXT,
    chief_complaint TEXT,
    diagnosis       TEXT,
    appointment_id  UUID,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- IMAGING ORDERS
CREATE TABLE imaging_orders (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name   TEXT,
    doctor_id      UUID,
    doctor_name    TEXT,
    imaging_tests  TEXT,
    status         TEXT DEFAULT 'PendingBilling',
    billing_status TEXT DEFAULT 'Unpaid',
    reviewed       BOOLEAN DEFAULT FALSE,
    results        TEXT,
    authorized_by  TEXT,
    payment_method TEXT,
    auth_code      TEXT,
    ward           TEXT,
    priority       TEXT,
    appointment_id UUID,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- PHARMACY INVENTORY
CREATE TABLE pharmacy_inventory (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    category   TEXT,
    quantity   INT DEFAULT 0,
    stock      INT DEFAULT 0,       -- used by frontend
    price      NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PRESCRIPTIONS
CREATE TABLE prescriptions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name   TEXT,
    doctor_id      UUID,
    doctor_name    TEXT,
    medications    TEXT,
    drugs          TEXT,           -- alias used by pharmacy frontend
    dosage         TEXT,
    notes          TEXT,
    status         TEXT DEFAULT 'Pending',
    billing_status TEXT,
    payment_method TEXT,
    auth_code      TEXT,
    appointment_id UUID,
    processed_at   TIMESTAMPTZ,
    dispensed_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ADMISSIONS
CREATE TABLE admissions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id           UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name         TEXT,
    room_id              UUID,
    room_name            TEXT,
    bed_number           TEXT,
    status               TEXT DEFAULT 'Recommended',
    authorized_by        TEXT,
    authorized_at        TIMESTAMPTZ,
    deposit              NUMERIC DEFAULT 0,
    daily_rate           NUMERIC DEFAULT 0,
    last_billing_date    TIMESTAMPTZ,
    next_billing_date    TIMESTAMPTZ,
    current_balance      NUMERIC DEFAULT 0,
    billing_cycle_status TEXT,
    last_renewal_by      TEXT,
    last_renewal_at      TIMESTAMPTZ,
    discharge_ready_at   TIMESTAMPTZ,
    discharge_summary    JSONB,
    discharged_at        TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- BILLING
CREATE TABLE billing (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id       UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name     TEXT,
    appointment_id   UUID,
    type             TEXT NOT NULL,
    description      TEXT,
    amount           NUMERIC DEFAULT 0,
    status           TEXT DEFAULT 'Pending',
    source           TEXT,
    payment_method   TEXT,
    auth_code        TEXT,
    rejection_reason TEXT,
    prescription_id  UUID,
    imaging_order_id UUID,
    lab_order_id     UUID,
    admission_id     UUID,
    paid_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- EXPENSES
CREATE TABLE expenses (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amount      NUMERIC DEFAULT 0,
    category    TEXT,
    description TEXT,
    status      TEXT DEFAULT 'Recorded',
    recorded_by TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- NOTIFICATIONS
CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID,
    message    TEXT NOT NULL,
    read       BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- AUDIT LOGS
CREATE TABLE audit_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp     TIMESTAMPTZ DEFAULT NOW(),
    user_id       UUID,
    user_name     TEXT,
    user_role     TEXT,
    ward          TEXT,
    action        TEXT,
    resource_type TEXT,
    resource_id   TEXT,
    details       TEXT,
    severity      TEXT DEFAULT 'INFO',
    created_at    TIMESTAMPTZ DEFAULT NOW()
);


-- ── STEP 6: SEED DEFAULT DATA ────────────────────────────────────

INSERT INTO settings (setting_key, setting_value)
VALUES ('appointmentFee', '{"amount": 5000}')
ON CONFLICT (setting_key) DO NOTHING;

INSERT INTO departments (name) VALUES
    ('General Outpatient'),
    ('Pediatrics'),
    ('Obstetrics & Gynecology'),
    ('Internal Medicine'),
    ('Surgery')
ON CONFLICT (name) DO NOTHING;

INSERT INTO rooms (name, capacity, total_beds, occupied_beds) VALUES
    ('Ward A (Male)',    10, 10, 0),
    ('Ward B (Female)', 10, 10, 0),
    ('ICU Room 1',       2,  2, 0),
    ('Private Suite 1',  1,  1, 0)
ON CONFLICT DO NOTHING;

INSERT INTO tariffs (name, amount) VALUES
    ('General Consultation',           3000),
    ('Specialist Consultation',        8000),
    ('Full Blood Count (FBC) Lab Test', 4500),
    ('Malaria Parasite (MP) Test',     1500),
    ('Chest X-Ray',                    7500),
    ('Abdominal Ultrasound Scan',     12000)
ON CONFLICT (name) DO NOTHING;


-- ── STEP 7: ENABLE ROW LEVEL SECURITY ───────────────────────────

ALTER TABLE settings           ENABLE ROW LEVEL SECURITY;
ALTER TABLE users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients           ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tariffs            ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_notes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_notes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_orders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE imaging_orders     ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing            ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses           ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs         ENABLE ROW LEVEL SECURITY;


-- ── STEP 8: RLS POLICIES ─────────────────────────────────────────

-- SETTINGS
CREATE POLICY "Read settings" ON settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admin write settings" ON settings FOR ALL TO authenticated USING (has_role('Admin') OR is_super_admin());

-- USERS
CREATE POLICY "Read users (auth)" ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read users (anon login)" ON users FOR SELECT TO anon USING (true);
CREATE POLICY "Write users" ON users FOR ALL TO authenticated USING (
    is_super_admin() OR auth.uid() = id OR has_role('Admin')
);

-- PATIENTS
CREATE POLICY "Read patients" ON patients FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write patients" ON patients FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Receptionist') OR has_role('Nurse') OR has_role('Doctor')
);

-- DEPARTMENTS / ROOMS / TARIFFS
CREATE POLICY "Read departments" ON departments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admin write departments" ON departments FOR ALL TO authenticated USING (has_role('Admin') OR is_super_admin());

CREATE POLICY "Read rooms" ON rooms FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write rooms" ON rooms FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Biller') OR has_role('Nurse') OR is_super_admin()
);

CREATE POLICY "Read tariffs" ON tariffs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admin write tariffs" ON tariffs FOR ALL TO authenticated USING (has_role('Admin') OR is_super_admin());

-- APPOINTMENTS
CREATE POLICY "Read appointments" ON appointments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Create appointments" ON appointments FOR INSERT TO authenticated WITH CHECK (
    has_role('Admin') OR has_role('Receptionist') OR has_role('Doctor') OR has_role('Biller') OR has_role('Nurse') OR has_role('Laboratory')
);
CREATE POLICY "Update appointments" ON appointments FOR UPDATE TO authenticated USING (
    has_role('Admin') OR has_role('Receptionist') OR has_role('Doctor') OR has_role('Biller') OR has_role('Nurse')
);
CREATE POLICY "Delete appointments" ON appointments FOR DELETE TO authenticated USING (has_role('Admin'));

-- CLINICAL NOTES
CREATE POLICY "Read clinical_notes" ON clinical_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Create clinical_notes" ON clinical_notes FOR INSERT TO authenticated WITH CHECK (
    has_role('Admin') OR has_role('Doctor') OR has_role('Nurse') OR has_role('Laboratory') OR has_role('Radiology')
);
CREATE POLICY "Admin modify clinical_notes" ON clinical_notes FOR UPDATE TO authenticated USING (has_role('Admin'));
CREATE POLICY "Admin delete clinical_notes" ON clinical_notes FOR DELETE TO authenticated USING (has_role('Admin'));

-- PROGRESS NOTES
CREATE POLICY "Read progress_notes" ON progress_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Create progress_notes" ON progress_notes FOR INSERT TO authenticated WITH CHECK (
    has_role('Admin') OR has_role('Doctor') OR has_role('Nurse') OR has_role('Laboratory') OR has_role('Radiology')
);
CREATE POLICY "Admin modify progress_notes" ON progress_notes FOR UPDATE TO authenticated USING (has_role('Admin'));
CREATE POLICY "Admin delete progress_notes" ON progress_notes FOR DELETE TO authenticated USING (has_role('Admin'));

-- LAB ORDERS
CREATE POLICY "Read lab_orders" ON lab_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write lab_orders" ON lab_orders FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Doctor') OR has_role('Laboratory') OR has_role('Biller')
);

-- IMAGING ORDERS
CREATE POLICY "Read imaging_orders" ON imaging_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write imaging_orders" ON imaging_orders FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Doctor') OR has_role('Radiology') OR has_role('Biller')
);

-- PHARMACY INVENTORY
CREATE POLICY "Read pharmacy_inventory" ON pharmacy_inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write pharmacy_inventory" ON pharmacy_inventory FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Pharmacist')
);

-- PRESCRIPTIONS
CREATE POLICY "Read prescriptions" ON prescriptions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write prescriptions" ON prescriptions FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Doctor') OR has_role('Pharmacist') OR has_role('Biller')
);

-- ADMISSIONS
CREATE POLICY "Read admissions" ON admissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Create admissions" ON admissions FOR INSERT TO authenticated WITH CHECK (
    has_role('Admin') OR has_role('Doctor')
);
CREATE POLICY "Update admissions" ON admissions FOR UPDATE TO authenticated USING (
    has_role('Admin') OR has_role('Doctor') OR has_role('Biller') OR has_role('Nurse')
);
CREATE POLICY "Delete admissions" ON admissions FOR DELETE TO authenticated USING (has_role('Admin'));

-- BILLING
CREATE POLICY "Read billing" ON billing FOR SELECT TO authenticated USING (true);
CREATE POLICY "Create billing" ON billing FOR INSERT TO authenticated WITH CHECK (
    has_role('Admin') OR has_role('Biller') OR has_role('Pharmacist') OR has_role('Doctor')
);
CREATE POLICY "Update billing" ON billing FOR UPDATE TO authenticated USING (
    has_role('Admin') OR has_role('Biller')
);
CREATE POLICY "Delete billing" ON billing FOR DELETE TO authenticated USING (has_role('Admin'));

-- EXPENSES
CREATE POLICY "Read expenses" ON expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Write expenses" ON expenses FOR ALL TO authenticated USING (
    has_role('Admin') OR has_role('Biller')
);

-- NOTIFICATIONS
CREATE POLICY "Manage notifications" ON notifications FOR ALL TO authenticated USING (true);

-- AUDIT LOGS
CREATE POLICY "Admin view audit_logs" ON audit_logs FOR SELECT TO authenticated USING (
    has_role('Admin') OR is_super_admin()
);
CREATE POLICY "Create audit_logs" ON audit_logs FOR INSERT TO authenticated WITH CHECK (true);


-- ── STEP 9: RELOAD POSTGREST SCHEMA CACHE ───────────────────────
-- This instantly clears ALL "column not found in schema cache" errors.
NOTIFY pgrst, 'reload schema';
