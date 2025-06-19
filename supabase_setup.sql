-- Car Service App Database Setup
-- Supabase SQL Editor'de bu SQL'i çalıştır

-- 1. User Profiles tablosu (Auth ile otomatik gelen users tablosuna ek bilgiler)
CREATE TABLE user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  phone_number TEXT,
  profile_image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Cars tablosu
CREATE TABLE cars (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  license_plate TEXT,
  year TEXT NOT NULL,
  color TEXT,
  mileage INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Maintenance Records tablosu
CREATE TABLE maintenance_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  car_id UUID REFERENCES cars(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  maintenance_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  date_performed DATE NOT NULL,
  mileage_at_service INTEGER,
  cost DECIMAL(10,2),
  service_provider TEXT,
  notes TEXT,
  status TEXT DEFAULT 'completed',
  next_service_date DATE,
  next_service_mileage INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Row Level Security (RLS) aktif et
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cars ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies - User Profiles
CREATE POLICY "Users can view own profile" 
  ON user_profiles FOR SELECT 
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
  ON user_profiles FOR UPDATE 
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" 
  ON user_profiles FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- 6. RLS Policies - Cars
CREATE POLICY "Users can view own cars" 
  ON cars FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own cars" 
  ON cars FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cars" 
  ON cars FOR UPDATE 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own cars" 
  ON cars FOR DELETE 
  USING (auth.uid() = user_id);

-- 7. RLS Policies - Maintenance Records
CREATE POLICY "Users can view own maintenance" 
  ON maintenance_records FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own maintenance" 
  ON maintenance_records FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own maintenance" 
  ON maintenance_records FOR UPDATE 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own maintenance" 
  ON maintenance_records FOR DELETE 
  USING (auth.uid() = user_id);

-- 8. Functions - User Profile otomatik oluşturma
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Trigger - Yeni user kaydolduğunda profil oluştur
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 10. Updated_at otomatik güncelleme fonksiyonu
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Updated_at triggers
CREATE TRIGGER handle_updated_at_user_profiles
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

CREATE TRIGGER handle_updated_at_cars
  BEFORE UPDATE ON cars
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

CREATE TRIGGER handle_updated_at_maintenance
  BEFORE UPDATE ON maintenance_records
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at(); 