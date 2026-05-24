-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create Settings Table
CREATE TABLE IF NOT EXISTS settings (
    setting_key TEXT PRIMARY KEY,
    setting_value JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert Default Appointment Fee Setting
INSERT INTO settings (setting_key, setting_value)
VALUES ('appointmentFee', '{"amount": 5000}')
ON CONFLICT (setting_key) DO NOTHING;

-- 3. Create Users (Staff Profiles) Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Links to Supabase Auth UID
    email TEXT UNIQUE NOT NULL,
    username TEXT,
    password TEXT,
    name TEXT NOT NULL,
    role TEXT NOT NULL, -- e.g. Doctor, Nurse, Admin, Receptionist, Biller, Pharmacist, Laboratory, Radiology
    specialty TEXT,
    is_active BOOLEAN DEFAULT FALSE,
    linked_uid UUID,
    last_verified_at TIMESTAMPTZ,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMPTZ,
    admin_verification_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create Patients Table
CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    surname TEXT,
    first_name TEXT,
    other_names TEXT,
    dob DATE,
    age INT,
    gender TEXT,
    marital_status TEXT,
    occupation TEXT,
    phone_primary TEXT UNIQUE, -- Nullable: saved as NULL when not provided
    phone_secondary TEXT,
    email TEXT,
    address TEXT,
    state TEXT,
    lga TEXT,
    nok_full_name TEXT,
    nok_relationship TEXT,
    nok_phone TEXT,
    nok_address TEXT,
    payment_type TEXT DEFAULT 'Cash',
    hmo_provider TEXT,
    hmo_id TEXT,
    auth_code TEXT,
    coverage_details TEXT,
    emergency_contact_same_as_nok BOOLEAN DEFAULT TRUE,
    emergency_name TEXT,
    emergency_phone TEXT,
    emergency_address TEXT,
    photo TEXT,
    registered_by TEXT,
    status TEXT DEFAULT 'Active',
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create Appointments Table
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    doctor_id UUID,
    doctor_name TEXT,
    status TEXT DEFAULT 'PendingBilling',
    billing_status TEXT DEFAULT 'Unpaid',
    appointment_fee NUMERIC DEFAULT 0,
    vitals JSONB,
    ward TEXT,
    condition TEXT,
    authorized_by TEXT,
    payment_method TEXT,
    auth_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Create Clinical Notes Table
CREATE TABLE IF NOT EXISTS clinical_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    doctor_id UUID,
    doctor_name TEXT,
    notes TEXT,
    diagnosis TEXT,
    symptoms TEXT,
    treatment_plan TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Create Progress Notes Table
CREATE TABLE IF NOT EXISTS progress_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    author_id UUID,
    author_name TEXT,
    author_role TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Create Billing Table
CREATE TABLE IF NOT EXISTS billing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
    type TEXT NOT NULL,
    description TEXT,
    amount NUMERIC DEFAULT 0,
    status TEXT DEFAULT 'Pending',
    source TEXT,
    payment_method TEXT,
    auth_code TEXT,
    rejection_reason TEXT,
    prescription_id UUID,
    imaging_order_id UUID,
    lab_order_id UUID,
    admission_id UUID,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Create Expenses Table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amount NUMERIC DEFAULT 0,
    category TEXT,
    description TEXT,
    status TEXT DEFAULT 'Recorded',
    recorded_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Create Lab Orders Table
CREATE TABLE IF NOT EXISTS lab_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    doctor_id UUID,
    doctor_name TEXT,
    lab_tests TEXT,
    status TEXT DEFAULT 'PendingBilling',
    billing_status TEXT DEFAULT 'Unpaid',
    reviewed BOOLEAN DEFAULT FALSE,
    results TEXT,
    authorized_by TEXT,
    payment_method TEXT,
    auth_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Create Imaging Orders Table
CREATE TABLE IF NOT EXISTS imaging_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    doctor_id UUID,
    doctor_name TEXT,
    imaging_tests TEXT,
    status TEXT DEFAULT 'PendingBilling',
    billing_status TEXT DEFAULT 'Unpaid',
    reviewed BOOLEAN DEFAULT FALSE,
    results TEXT,
    authorized_by TEXT,
    payment_method TEXT,
    auth_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Create Pharmacy Inventory Table
CREATE TABLE IF NOT EXISTS pharmacy_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT,
    quantity INT DEFAULT 0,
    price NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Create Prescriptions Table
CREATE TABLE IF NOT EXISTS prescriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    doctor_id UUID,
    doctor_name TEXT,
    medications TEXT,
    dosage TEXT,
    status TEXT DEFAULT 'Pending',
    payment_method TEXT,
    auth_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. Create Admissions Table
CREATE TABLE IF NOT EXISTS admissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    patient_name TEXT,
    room_id UUID,
    room_name TEXT,
    bed_number TEXT,
    status TEXT DEFAULT 'Recommended',
    authorized_by TEXT,
    authorized_at TIMESTAMPTZ,
    last_billing_date TIMESTAMPTZ,
    next_billing_date TIMESTAMPTZ,
    current_balance NUMERIC DEFAULT 0,
    billing_cycle_status TEXT,
    last_renewal_by TEXT,
    last_renewal_at TIMESTAMPTZ,
    discharge_ready_at TIMESTAMPTZ,
    discharge_summary JSONB,
    discharged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. Create Departments Table
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 16. Create Rooms Table
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    occupied_beds INT DEFAULT 0,
    total_beds INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 17. Create Tariffs Table
CREATE TABLE IF NOT EXISTS tariffs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    amount NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 18. Create Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------
-- Row Level Security (RLS) is now ENABLED and enforced.
-- See supabase_policies.sql for all role-based access policies.
-- ----------------------------------------------------

-- Insert initial mockup data for departments, rooms, tariffs
INSERT INTO departments (name) VALUES 
('General Outpatient'),
('Pediatrics'),
('Obstetrics & Gynecology'),
('Internal Medicine'),
('Surgery')
ON CONFLICT (name) DO NOTHING;

INSERT INTO rooms (name, occupied_beds, total_beds) VALUES
('Ward A (Male)', 0, 10),
('Ward B (Female)', 0, 10),
('ICU Room 1', 0, 2),
('Private Suite 1', 0, 1)
ON CONFLICT DO NOTHING;

INSERT INTO tariffs (name, amount) VALUES
('General Consultation', 3000),
('Specialist Consultation', 8000),
('Full Blood Count (FBC) Lab Test', 4500),
('Malaria Parasite (MP) Test', 1500),
('Chest X-Ray', 7500),
('Abdominal Ultrasound Scan', 12000)
ON CONFLICT (name) DO NOTHING;
