-- Create shift_porter_absences table
CREATE TABLE IF NOT EXISTS "public"."shift_porter_absences" (
    "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
    "shift_id" UUID NOT NULL,
    "porter_id" UUID NOT NULL,
    "start_time" TIME NOT NULL,
    "end_time" TIME NOT NULL,
    "absence_reason" VARCHAR(15),
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    PRIMARY KEY ("id"),
    FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE,
    FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS "shift_porter_absences_shift_id_idx" ON "public"."shift_porter_absences" ("shift_id");
CREATE INDEX IF NOT EXISTS "shift_porter_absences_porter_id_idx" ON "public"."shift_porter_absences" ("porter_id");

-- Add RLS policies
ALTER TABLE "public"."shift_porter_absences" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON "public"."shift_porter_absences"
    FOR SELECT USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON "public"."shift_porter_absences"
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update access for authenticated users" ON "public"."shift_porter_absences"
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete access for authenticated users" ON "public"."shift_porter_absences"
    FOR DELETE USING (auth.role() = 'authenticated');
