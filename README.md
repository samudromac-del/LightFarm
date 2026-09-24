# LightFarm

A Flutter app for managing agricultural land data across regions. Built with Flutter and Supabase.

## What it does

- **Farmers** can log in and update their land area
- **Local Government** users can view all farmers in their region with total acreage
- **Admins** have a reserved dashboard for future use

## Tech Stack

- Flutter (Dart)
- Supabase (auth + database)

---

## Clone and Run

### Requirements
- [Flutter](https://docs.flutter.dev/get-started/install) installed
- A Supabase account (free at [supabase.com](https://supabase.com))

### Steps

```bash
git clone https://github.com/samudromac-del/LightFarm.git
cd LightFarm
flutter pub get
flutter run
```

The app is pre-configured with a working Supabase backend — you can run it as-is to test it.

---

## Set Up Your Own Backend (Optional)

If you want your own Supabase project instead of using the shared one:

### 1. Create a Supabase project
Go to [supabase.com](https://supabase.com) → New Project

### 2. Create the profiles table

Run this in the Supabase **SQL Editor**:

```sql
-- Create role enum
CREATE TYPE user_role AS ENUM ('farmer', 'local_gov', 'admin');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT,
  role user_role,
  phone TEXT,
  location TEXT,
  area DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, location)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    (NEW.raw_user_meta_data->>'role')::user_role,
    NEW.raw_user_meta_data->>'location'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

### 3. Set RLS policies

```sql
-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Allow reading farmer profiles (for local_gov dashboard)
CREATE POLICY "Authenticated users can view farmer profiles"
  ON public.profiles FOR SELECT
  USING (role = 'farmer');
```

### 4. Disable email confirmation
In Supabase → Authentication → Settings → turn off **Email Confirmations**

### 5. Update credentials
Open `lib/supabase_config.dart` and replace with your project's URL and anon key:

```dart
class SupabaseConfig{
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseKey = 'YOUR_ANON_KEY';
}
```

---

## Project Structure

```
lib/
├── main.dart            # App entry point + auth routing
├── supabase_config.dart # Supabase credentials
├── auth_service.dart    # Sign up, login, logout, get profile
├── farm_service.dart    # Update land area, get farmers by region
├── login_screen.dart    # Login UI
├── signup_screen.dart   # Sign up UI
└── home_screen.dart     # Role-based dashboard
```

## Roles

| Role | Access |
|---|---|
| `farmer` | View region & land area, update acreage |
| `local_gov` | View all farmers in their region with totals |
| `admin` | Admin dashboard (placeholder) |
