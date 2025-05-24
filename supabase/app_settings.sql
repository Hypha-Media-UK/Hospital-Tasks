-- Create the app_settings table
CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "timezone" "text" DEFAULT 'UTC' NOT NULL,
    "time_format" "text" DEFAULT '24h' NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "app_settings_pkey" PRIMARY KEY ("id")
);

-- Add update trigger to keep updated_at current
CREATE TRIGGER "update_app_settings_updated_at"
BEFORE UPDATE ON "public"."app_settings"
FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();

-- Grant permissions
GRANT ALL ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."app_settings" TO "service_role";

-- Insert default settings
INSERT INTO "public"."app_settings" ("timezone", "time_format")
VALUES ('UTC', '24h');
