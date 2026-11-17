-- ============================================================================
-- Table: public.authentification
-- Gère les comptes Admin et Clients avec unicité par email
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.authentification (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  prenom TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  tel TEXT,
  mot_de_passe TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'client')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index unique insensible à la casse sur email (sécurité supplémentaire)
CREATE UNIQUE INDEX IF NOT EXISTS authentification_email_lower_idx
  ON public.authentification (LOWER(email));

-- Activer Row Level Security et autoriser l'application Flutter (clé anon)
ALTER TABLE public.authentification ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all operations on authentification" ON public.authentification;
CREATE POLICY "Allow all operations on authentification"
  ON public.authentification
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Insertion / mise à jour du compte Administrateur par défaut
INSERT INTO public.authentification (id, nom, prenom, email, tel, mot_de_passe, role)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Admin',
  'Système',
  'admin@gmail.com',
  '00000000',
  '123456',
  'admin'
)
ON CONFLICT (email) DO UPDATE
  SET mot_de_passe = EXCLUDED.mot_de_passe,
      role = 'admin';
