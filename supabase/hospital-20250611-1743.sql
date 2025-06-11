

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."staff_role" AS ENUM (
    'supervisor',
    'porter'
);


ALTER TYPE "public"."staff_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."copy_defaults_on_shift_creation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  PERFORM copy_defaults_to_shift(NEW.id, NEW.shift_type);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."copy_defaults_on_shift_creation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_area_cover_assignment_id UUID;
  v_service_cover_assignment_id UUID;
  v_default_area_cover_id UUID;
  v_default_service_cover_id UUID;
  r_area_assignment RECORD;
  r_service_assignment RECORD;
  r_area_porter RECORD;
  r_service_porter RECORD;
  v_porter_count INTEGER;
  v_debug_info TEXT;
BEGIN
  -- Initialize debug info
  v_debug_info := 'Starting copy_defaults_to_shift for shift_id: ' || p_shift_id || ', shift_type: ' || p_shift_type;

  -- Copy area cover assignments from defaults to shift
  FOR r_area_assignment IN
    SELECT * FROM default_area_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := v_debug_info || E'\nProcessing area cover assignment: ' || r_area_assignment.id;

    -- Insert into shift_area_cover_assignments with day-specific minimum porter counts
    INSERT INTO shift_area_cover_assignments (
      shift_id, department_id, start_time, end_time, color,
      minimum_porters, minimum_porters_mon, minimum_porters_tue, 
      minimum_porters_wed, minimum_porters_thu, minimum_porters_fri, 
      minimum_porters_sat, minimum_porters_sun
    ) VALUES (
      p_shift_id, r_area_assignment.department_id, r_area_assignment.start_time,
      r_area_assignment.end_time, r_area_assignment.color,
      r_area_assignment.minimum_porters, r_area_assignment.minimum_porters_mon, 
      r_area_assignment.minimum_porters_tue, r_area_assignment.minimum_porters_wed, 
      r_area_assignment.minimum_porters_thu, r_area_assignment.minimum_porters_fri, 
      r_area_assignment.minimum_porters_sat, r_area_assignment.minimum_porters_sun
    ) RETURNING id INTO v_area_cover_assignment_id;

    -- Store the default ID for later
    v_default_area_cover_id := r_area_assignment.id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Created shift_area_cover_assignment: ' || v_area_cover_assignment_id;

    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count
    FROM default_area_cover_porter_assignments
    WHERE default_area_cover_assignment_id = v_default_area_cover_id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Found ' || v_porter_count || ' porter assignments to copy';

    -- Copy porter assignments for this area cover
    FOR r_area_porter IN
      SELECT * FROM default_area_cover_porter_assignments
      WHERE default_area_cover_assignment_id = v_default_area_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Processing porter assignment: ' || r_area_porter.id;

      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_area_cover_assignment_id, r_area_porter.porter_id,
        r_area_porter.start_time, r_area_porter.end_time
      );

      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Created porter assignment for porter_id: ' || r_area_porter.porter_id;
    END LOOP;
  END LOOP;

  -- Copy service cover assignments from defaults to shift
  FOR r_service_assignment IN
    SELECT * FROM default_service_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := v_debug_info || E'\nProcessing service cover assignment: ' || r_service_assignment.id;

    -- Insert into shift_support_service_assignments with day-specific minimum porter counts
    INSERT INTO shift_support_service_assignments (
      shift_id, service_id, start_time, end_time, color,
      minimum_porters, minimum_porters_mon, minimum_porters_tue, 
      minimum_porters_wed, minimum_porters_thu, minimum_porters_fri, 
      minimum_porters_sat, minimum_porters_sun
    ) VALUES (
      p_shift_id, r_service_assignment.service_id, r_service_assignment.start_time,
      r_service_assignment.end_time, r_service_assignment.color,
      r_service_assignment.minimum_porters, r_service_assignment.minimum_porters_mon, 
      r_service_assignment.minimum_porters_tue, r_service_assignment.minimum_porters_wed, 
      r_service_assignment.minimum_porters_thu, r_service_assignment.minimum_porters_fri, 
      r_service_assignment.minimum_porters_sat, r_service_assignment.minimum_porters_sun
    ) RETURNING id INTO v_service_cover_assignment_id;

    -- Store the default ID for later
    v_default_service_cover_id := r_service_assignment.id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Created shift_support_service_assignment: ' || v_service_cover_assignment_id;

    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count
    FROM default_service_cover_porter_assignments
    WHERE default_service_cover_assignment_id = v_default_service_cover_id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Found ' || v_porter_count || ' porter assignments to copy';

    -- Copy porter assignments for this service cover
    FOR r_service_porter IN
      SELECT * FROM default_service_cover_porter_assignments
      WHERE default_service_cover_assignment_id = v_default_service_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Processing porter assignment: ' || r_service_porter.id;

      INSERT INTO shift_support_service_porter_assignments (
        shift_support_service_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_service_cover_assignment_id, r_service_porter.porter_id,
        r_service_porter.start_time, r_service_porter.end_time
      );

      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Created porter assignment for porter_id: ' || r_service_porter.porter_id;
    END LOOP;
  END LOOP;

  -- Log debug info (optional)
  -- RAISE NOTICE '%', v_debug_info;
END;
$$;


ALTER FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) IS 'Copies default area cover and service cover assignments to a new shift. 
This version includes better error handling and debugging to ensure porter assignments 
are properly copied from default_service_cover_porter_assignments to 
shift_support_service_porter_assignments.';



CREATE OR REPLACE FUNCTION "public"."update_modified_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_modified_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "timezone" "text" DEFAULT 'UTC'::"text" NOT NULL,
    "time_format" "text" DEFAULT '24h'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "department_id" "uuid" NOT NULL,
    "porter_id" "uuid",
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "shift_type" "text",
    CONSTRAINT "new_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."area_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."area_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "area_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."area_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."buildings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0
);


ALTER TABLE "public"."buildings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "department_id" "uuid" NOT NULL,
    "shift_type" character varying(20) NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "color" character varying(20) DEFAULT '#4285F4'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1,
    CONSTRAINT "default_area_cover_assignments_shift_type_check" CHECK ((("shift_type")::"text" = ANY (ARRAY[('week_day'::character varying)::"text", ('week_night'::character varying)::"text", ('weekend_day'::character varying)::"text", ('weekend_night'::character varying)::"text"])))
);


ALTER TABLE "public"."default_area_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_area_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "default_area_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."default_area_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_service_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "service_id" "uuid" NOT NULL,
    "shift_type" character varying(20) NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "color" character varying(20) DEFAULT '#4285F4'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1,
    CONSTRAINT "default_service_cover_assignments_shift_type_check" CHECK ((("shift_type")::"text" = ANY (ARRAY[('week_day'::character varying)::"text", ('week_night'::character varying)::"text", ('weekend_day'::character varying)::"text", ('weekend_night'::character varying)::"text"])))
);


ALTER TABLE "public"."default_service_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_service_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "default_service_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."default_service_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."department_task_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "department_id" "uuid",
    "task_type_id" "uuid",
    "task_item_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."department_task_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."departments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "building_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_frequent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0,
    "color" character varying(20) DEFAULT '#CCCCCC'::character varying
);


ALTER TABLE "public"."departments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."departments"."color" IS 'Department color used for consistent visual representation across the application';



CREATE TABLE IF NOT EXISTS "public"."porter_absences" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "absence_type" character varying(20) NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "notes" "text"
);


ALTER TABLE "public"."porter_absences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1
);


ALTER TABLE "public"."shift_area_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_area_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_area_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_area_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_defaults" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_type" "text" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shift_defaults" OWNER TO "postgres";


COMMENT ON TABLE "public"."shift_defaults" IS 'Stores default shift times and colors';



CREATE TABLE IF NOT EXISTS "public"."shift_porter_pool" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_porter_pool" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_support_service_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "service_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1
);


ALTER TABLE "public"."shift_support_service_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_support_service_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_support_service_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_support_service_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_tasks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "task_item_id" "uuid" NOT NULL,
    "porter_id" "uuid",
    "origin_department_id" "uuid",
    "destination_department_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "time_received" "text" DEFAULT '00:00'::"text" NOT NULL,
    "time_allocated" "text" DEFAULT '00:01'::"text" NOT NULL,
    "time_completed" "text" DEFAULT '00:20'::"text" NOT NULL,
    CONSTRAINT "shift_tasks_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."shift_tasks" OWNER TO "postgres";


COMMENT ON TABLE "public"."shift_tasks" IS 'Task tracking table with time fields as text to avoid timezone issues';



CREATE TABLE IF NOT EXISTS "public"."shift_tasks_backup" (
    "id" "uuid",
    "shift_id" "uuid",
    "task_item_id" "uuid",
    "porter_id" "uuid",
    "origin_department_id" "uuid",
    "destination_department_id" "uuid",
    "status" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "time_received" timestamp with time zone,
    "time_allocated" timestamp with time zone,
    "time_completed" timestamp with time zone
);


ALTER TABLE "public"."shift_tasks_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shifts" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "supervisor_id" "uuid" NOT NULL,
    "shift_type" "text" NOT NULL,
    "start_time" timestamp with time zone DEFAULT "now"() NOT NULL,
    "end_time" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "shifts_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "role" "public"."staff_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "department_id" "uuid",
    "porter_type" "text" DEFAULT 'shift'::"text",
    "availability_pattern" character varying(50),
    "contracted_hours_start" time without time zone,
    "contracted_hours_end" time without time zone,
    CONSTRAINT "check_porter_type" CHECK ((("porter_type" = ANY (ARRAY['shift'::"text", 'relief'::"text"])) OR ("porter_type" IS NULL)))
);


ALTER TABLE "public"."staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_department_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."staff_department_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_service_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "service_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "shift_type" "text",
    CONSTRAINT "support_service_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."support_service_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_service_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "support_service_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."support_service_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_services" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."support_services" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_item_department_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_item_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "is_origin" boolean DEFAULT false,
    "is_destination" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_item_department_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_type_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_regular" boolean DEFAULT false
);


ALTER TABLE "public"."task_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_type_department_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_type_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "is_origin" boolean DEFAULT false,
    "is_destination" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_type_department_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_types" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_types" OWNER TO "postgres";


ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."area_cover_assignments"
    ADD CONSTRAINT "area_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_area_cover_assignment_id_port_key" UNIQUE ("area_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."buildings"
    ADD CONSTRAINT "buildings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_area_cover_assignments"
    ADD CONSTRAINT "default_area_cover_assignments_department_id_shift_type_key" UNIQUE ("department_id", "shift_type");



ALTER TABLE ONLY "public"."default_area_cover_assignments"
    ADD CONSTRAINT "default_area_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_ass_default_area_cover_assignment_key" UNIQUE ("default_area_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_service_cover_assignments"
    ADD CONSTRAINT "default_service_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_service_cover_assignments"
    ADD CONSTRAINT "default_service_cover_assignments_service_id_shift_type_key" UNIQUE ("service_id", "shift_type");



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter__default_service_cover_assignm_key" UNIQUE ("default_service_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_department_id_key" UNIQUE ("department_id");



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."porter_absences"
    ADD CONSTRAINT "porter_absences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_shift_id_department_id_key" UNIQUE ("shift_id", "department_id");



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_shift_area_cover_assign_key" UNIQUE ("shift_area_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."shift_defaults"
    ADD CONSTRAINT "shift_defaults_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_defaults"
    ADD CONSTRAINT "shift_defaults_shift_type_key" UNIQUE ("shift_type");



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_shift_id_porter_id_key" UNIQUE ("shift_id", "porter_id");



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_shift_id_service_id_key" UNIQUE ("shift_id", "service_id");



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter__shift_support_service_assignm_key" UNIQUE ("shift_support_service_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_staff_id_department_id_key" UNIQUE ("staff_id", "department_id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_service_assignments"
    ADD CONSTRAINT "support_service_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assign_support_service_assignment_id_key" UNIQUE ("support_service_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_services"
    ADD CONSTRAINT "support_services_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."support_services"
    ADD CONSTRAINT "support_services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_task_item_id_department_id_key" UNIQUE ("task_item_id", "department_id");



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_task_type_id_department_id_key" UNIQUE ("task_type_id", "department_id");



ALTER TABLE ONLY "public"."task_types"
    ADD CONSTRAINT "task_types_pkey" PRIMARY KEY ("id");



CREATE INDEX "area_cover_assignments_department_id_idx" ON "public"."area_cover_assignments" USING "btree" ("department_id");



CREATE INDEX "area_cover_assignments_porter_id_idx" ON "public"."area_cover_assignments" USING "btree" ("porter_id");



CREATE INDEX "area_cover_porter_assignments_area_cover_id_idx" ON "public"."area_cover_porter_assignments" USING "btree" ("area_cover_assignment_id");



CREATE INDEX "area_cover_porter_assignments_porter_id_idx" ON "public"."area_cover_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "buildings_sort_order_idx" ON "public"."buildings" USING "btree" ("sort_order");



CREATE INDEX "departments_building_id_idx" ON "public"."departments" USING "btree" ("building_id");



CREATE INDEX "departments_is_frequent_idx" ON "public"."departments" USING "btree" ("is_frequent");



CREATE INDEX "departments_sort_order_idx" ON "public"."departments" USING "btree" ("sort_order");



CREATE INDEX "idx_default_area_cover_porter_assignment" ON "public"."default_area_cover_porter_assignments" USING "btree" ("default_area_cover_assignment_id");



CREATE INDEX "idx_default_area_cover_shift_type" ON "public"."default_area_cover_assignments" USING "btree" ("shift_type");



CREATE INDEX "idx_default_service_cover_porter_assignment" ON "public"."default_service_cover_porter_assignments" USING "btree" ("default_service_cover_assignment_id");



CREATE INDEX "idx_default_service_cover_shift_type" ON "public"."default_service_cover_assignments" USING "btree" ("shift_type");



CREATE INDEX "idx_porter_absences_dates" ON "public"."porter_absences" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_porter_absences_porter_id" ON "public"."porter_absences" USING "btree" ("porter_id");



CREATE INDEX "idx_shifts_is_active" ON "public"."shifts" USING "btree" ("is_active");



CREATE INDEX "idx_shifts_supervisor_id" ON "public"."shifts" USING "btree" ("supervisor_id");



CREATE INDEX "shift_area_cover_assignments_department_id_idx" ON "public"."shift_area_cover_assignments" USING "btree" ("department_id");



CREATE INDEX "shift_area_cover_assignments_shift_id_idx" ON "public"."shift_area_cover_assignments" USING "btree" ("shift_id");



CREATE INDEX "shift_area_cover_porter_assignments_porter_id_idx" ON "public"."shift_area_cover_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "shift_area_cover_porter_assignments_shift_area_cover_id_idx" ON "public"."shift_area_cover_porter_assignments" USING "btree" ("shift_area_cover_assignment_id");



CREATE INDEX "shift_porter_pool_porter_id_idx" ON "public"."shift_porter_pool" USING "btree" ("porter_id");



CREATE INDEX "shift_porter_pool_shift_id_idx" ON "public"."shift_porter_pool" USING "btree" ("shift_id");



CREATE INDEX "shift_support_service_assignments_service_id_idx" ON "public"."shift_support_service_assignments" USING "btree" ("service_id");



CREATE INDEX "shift_support_service_assignments_shift_id_idx" ON "public"."shift_support_service_assignments" USING "btree" ("shift_id");



CREATE INDEX "shift_support_service_porter_assignments_assignment_id_idx" ON "public"."shift_support_service_porter_assignments" USING "btree" ("shift_support_service_assignment_id");



CREATE INDEX "shift_support_service_porter_assignments_porter_id_idx" ON "public"."shift_support_service_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "shift_tasks_destination_department_id_idx" ON "public"."shift_tasks" USING "btree" ("destination_department_id");



CREATE INDEX "shift_tasks_origin_department_id_idx" ON "public"."shift_tasks" USING "btree" ("origin_department_id");



CREATE INDEX "shift_tasks_porter_id_idx" ON "public"."shift_tasks" USING "btree" ("porter_id");



CREATE INDEX "shift_tasks_shift_id_idx" ON "public"."shift_tasks" USING "btree" ("shift_id");



CREATE INDEX "shift_tasks_status_idx" ON "public"."shift_tasks" USING "btree" ("status");



CREATE INDEX "shift_tasks_task_item_id_idx" ON "public"."shift_tasks" USING "btree" ("task_item_id");



CREATE INDEX "shifts_is_active_idx" ON "public"."shifts" USING "btree" ("is_active");



CREATE INDEX "shifts_shift_type_idx" ON "public"."shifts" USING "btree" ("shift_type");



CREATE INDEX "shifts_supervisor_id_idx" ON "public"."shifts" USING "btree" ("supervisor_id");



CREATE INDEX "staff_department_id_idx" ON "public"."staff" USING "btree" ("department_id");



CREATE INDEX "staff_dept_dept_id_idx" ON "public"."staff_department_assignments" USING "btree" ("department_id");



CREATE INDEX "staff_dept_staff_id_idx" ON "public"."staff_department_assignments" USING "btree" ("staff_id");



CREATE INDEX "staff_role_idx" ON "public"."staff" USING "btree" ("role");



CREATE INDEX "support_service_assignments_service_id_idx" ON "public"."support_service_assignments" USING "btree" ("service_id");



CREATE INDEX "support_service_porter_assignments_porter_id_idx" ON "public"."support_service_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "support_service_porter_assignments_service_id_idx" ON "public"."support_service_porter_assignments" USING "btree" ("support_service_assignment_id");



CREATE INDEX "support_services_is_active_idx" ON "public"."support_services" USING "btree" ("is_active");



CREATE INDEX "task_item_dept_assign_dept_id_idx" ON "public"."task_item_department_assignments" USING "btree" ("department_id");



CREATE INDEX "task_item_dept_assign_task_item_id_idx" ON "public"."task_item_department_assignments" USING "btree" ("task_item_id");



CREATE INDEX "task_items_task_type_id_idx" ON "public"."task_items" USING "btree" ("task_type_id");



CREATE INDEX "task_type_dept_assign_dept_id_idx" ON "public"."task_type_department_assignments" USING "btree" ("department_id");



CREATE INDEX "task_type_dept_assign_task_type_id_idx" ON "public"."task_type_department_assignments" USING "btree" ("task_type_id");



CREATE OR REPLACE TRIGGER "copy_defaults_to_new_shift" AFTER INSERT ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."copy_defaults_on_shift_creation"();



CREATE OR REPLACE TRIGGER "update_app_settings_updated_at" BEFORE UPDATE ON "public"."app_settings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_porter_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_buildings_updated_at" BEFORE UPDATE ON "public"."buildings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_default_area_cover_assignments_timestamp" BEFORE UPDATE ON "public"."default_area_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_default_area_cover_porter_assignments_timestamp" BEFORE UPDATE ON "public"."default_area_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_default_service_cover_assignments_timestamp" BEFORE UPDATE ON "public"."default_service_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_default_service_cover_porter_assignments_timestamp" BEFORE UPDATE ON "public"."default_service_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_departments_updated_at" BEFORE UPDATE ON "public"."departments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_porter_pool_updated_at" BEFORE UPDATE ON "public"."shift_porter_pool" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_support_service_assignments_updated_at" BEFORE UPDATE ON "public"."shift_support_service_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_support_service_porter_assignments_updated_at" BEFORE UPDATE ON "public"."shift_support_service_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_tasks_updated_at" BEFORE UPDATE ON "public"."shift_tasks" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shifts_updated_at" BEFORE UPDATE ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_staff_updated_at" BEFORE UPDATE ON "public"."staff" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_support_service_assignments_updated_at" BEFORE UPDATE ON "public"."support_service_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_support_service_porter_assignments_updated_at" BEFORE UPDATE ON "public"."support_service_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_support_services_updated_at" BEFORE UPDATE ON "public"."support_services" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_task_items_updated_at" BEFORE UPDATE ON "public"."task_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_task_types_updated_at" BEFORE UPDATE ON "public"."task_types" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."area_cover_assignments"
    ADD CONSTRAINT "area_cover_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."area_cover_assignments"
    ADD CONSTRAINT "area_cover_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_area_cover_assignment_id_fkey" FOREIGN KEY ("area_cover_assignment_id") REFERENCES "public"."area_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_area_cover_assignments"
    ADD CONSTRAINT "default_area_cover_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_ass_default_area_cover_assignmen_fkey" FOREIGN KEY ("default_area_cover_assignment_id") REFERENCES "public"."default_area_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_service_cover_assignments"
    ADD CONSTRAINT "default_service_cover_assignments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."support_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter__default_service_cover_assign_fkey" FOREIGN KEY ("default_service_cover_assignment_id") REFERENCES "public"."default_service_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_task_item_id_fkey" FOREIGN KEY ("task_item_id") REFERENCES "public"."task_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_task_type_id_fkey" FOREIGN KEY ("task_type_id") REFERENCES "public"."task_types"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_building_id_fkey" FOREIGN KEY ("building_id") REFERENCES "public"."buildings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."porter_absences"
    ADD CONSTRAINT "porter_absences_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_shift_area_cover_assig_fkey" FOREIGN KEY ("shift_area_cover_assignment_id") REFERENCES "public"."shift_area_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."support_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter__shift_support_service_assign_fkey" FOREIGN KEY ("shift_support_service_assignment_id") REFERENCES "public"."shift_support_service_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_destination_department_id_fkey" FOREIGN KEY ("destination_department_id") REFERENCES "public"."departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_origin_department_id_fkey" FOREIGN KEY ("origin_department_id") REFERENCES "public"."departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_task_item_id_fkey" FOREIGN KEY ("task_item_id") REFERENCES "public"."task_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."support_service_assignments"
    ADD CONSTRAINT "support_service_assignments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."support_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assign_support_service_assignment_i_fkey" FOREIGN KEY ("support_service_assignment_id") REFERENCES "public"."support_service_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_task_item_id_fkey" FOREIGN KEY ("task_item_id") REFERENCES "public"."task_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_task_type_id_fkey" FOREIGN KEY ("task_type_id") REFERENCES "public"."task_types"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_task_type_id_fkey" FOREIGN KEY ("task_type_id") REFERENCES "public"."task_types"("id") ON DELETE CASCADE;



CREATE POLICY "Allow authenticated users full access to default area cover ass" ON "public"."default_area_cover_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users full access to default area cover por" ON "public"."default_area_cover_porter_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users full access to default service cover " ON "public"."default_service_cover_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users full access to default service cover " ON "public"."default_service_cover_porter_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to manage shift defaults" ON "public"."shift_defaults" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to manage shift tasks" ON "public"."shift_tasks" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to manage shifts" ON "public"."shifts" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to read all shift defaults" ON "public"."shift_defaults" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."copy_defaults_on_shift_creation"() TO "anon";
GRANT ALL ON FUNCTION "public"."copy_defaults_on_shift_creation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."copy_defaults_on_shift_creation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT ALL ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."app_settings" TO "service_role";



GRANT ALL ON TABLE "public"."area_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."area_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."area_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."area_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."area_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."area_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."buildings" TO "anon";
GRANT ALL ON TABLE "public"."buildings" TO "authenticated";
GRANT ALL ON TABLE "public"."buildings" TO "service_role";



GRANT ALL ON TABLE "public"."default_area_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_area_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_area_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."default_area_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_area_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_area_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."default_service_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_service_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_service_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."default_service_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_service_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_service_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."department_task_assignments" TO "anon";
GRANT ALL ON TABLE "public"."department_task_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."department_task_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."departments" TO "anon";
GRANT ALL ON TABLE "public"."departments" TO "authenticated";
GRANT ALL ON TABLE "public"."departments" TO "service_role";



GRANT ALL ON TABLE "public"."porter_absences" TO "anon";
GRANT ALL ON TABLE "public"."porter_absences" TO "authenticated";
GRANT ALL ON TABLE "public"."porter_absences" TO "service_role";



GRANT ALL ON TABLE "public"."shift_area_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_area_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_area_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_area_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_area_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_area_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_defaults" TO "anon";
GRANT ALL ON TABLE "public"."shift_defaults" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_defaults" TO "service_role";



GRANT ALL ON TABLE "public"."shift_porter_pool" TO "anon";
GRANT ALL ON TABLE "public"."shift_porter_pool" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_porter_pool" TO "service_role";



GRANT ALL ON TABLE "public"."shift_support_service_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_support_service_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_support_service_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_support_service_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_support_service_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_support_service_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_tasks" TO "anon";
GRANT ALL ON TABLE "public"."shift_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."shift_tasks_backup" TO "anon";
GRANT ALL ON TABLE "public"."shift_tasks_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_tasks_backup" TO "service_role";



GRANT ALL ON TABLE "public"."shifts" TO "anon";
GRANT ALL ON TABLE "public"."shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."shifts" TO "service_role";



GRANT ALL ON TABLE "public"."staff" TO "anon";
GRANT ALL ON TABLE "public"."staff" TO "authenticated";
GRANT ALL ON TABLE "public"."staff" TO "service_role";



GRANT ALL ON TABLE "public"."staff_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."staff_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_department_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."support_service_assignments" TO "anon";
GRANT ALL ON TABLE "public"."support_service_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."support_service_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."support_service_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."support_service_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."support_service_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."support_services" TO "anon";
GRANT ALL ON TABLE "public"."support_services" TO "authenticated";
GRANT ALL ON TABLE "public"."support_services" TO "service_role";



GRANT ALL ON TABLE "public"."task_item_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."task_item_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_item_department_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."task_items" TO "anon";
GRANT ALL ON TABLE "public"."task_items" TO "authenticated";
GRANT ALL ON TABLE "public"."task_items" TO "service_role";



GRANT ALL ON TABLE "public"."task_type_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."task_type_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_type_department_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."task_types" TO "anon";
GRANT ALL ON TABLE "public"."task_types" TO "authenticated";
GRANT ALL ON TABLE "public"."task_types" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: app_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."app_settings" ("id", "timezone", "time_format", "created_at", "updated_at") VALUES
	('d0457585-be03-44a4-a2c2-1669c6a9a7fc', 'UTC', '24h', '2025-05-24 11:53:29.67357+00', '2025-05-24 11:53:29.67357+00'),
	('76c2f394-4c47-4010-b0bd-b687398a495d', 'UTC', '12h', '2025-05-24 11:57:56.481832+00', '2025-05-24 11:57:56.215+00'),
	('63f99fa6-34e0-4ca5-b4a4-458d859d2766', 'GMT', '24h', '2025-05-24 11:58:53.469637+00', '2025-05-24 11:58:53.352+00'),
	('22639f07-209d-41e6-b3e3-f569b6c4db96', 'GMT', '24h', '2025-05-24 12:03:15.409004+00', '2025-05-24 12:03:15.198+00'),
	('fa5c9416-2b70-4b81-9f54-7ebaaac411c0', 'GMT', '24h', '2025-05-28 14:07:30.519927+00', '2025-05-28 14:07:27.858+00');


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."buildings" ("id", "name", "address", "created_at", "updated_at", "sort_order") VALUES
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-05-30 10:36:03.190794+00', 0),
	('e85c40e7-6f29-4e22-9787-6ed289c36429', 'Charlesworth Building', NULL, '2025-05-24 12:20:54.129832+00', '2025-05-30 10:36:03.190794+00', 10),
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ladysmith Building', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-30 10:36:03.190794+00', 20),
	('abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Stores', NULL, '2025-05-29 08:52:06.678532+00', '2025-05-30 10:36:03.190794+00', 30),
	('23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Portland Building', NULL, '2025-05-24 15:33:42.930237+00', '2025-05-30 10:36:03.190794+00', 40),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Werneth House', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-05-30 10:36:03.190794+00', 50),
	('d4d0bf79-eb71-477e-9d06-03159039e425', 'New Fountain House', NULL, '2025-05-24 12:20:27.560098+00', '2025-05-30 10:36:03.190794+00', 60),
	('e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Bereavement Centre', NULL, '2025-05-24 15:12:37.764027+00', '2025-05-30 10:36:03.190794+00', 70),
	('69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Unit', NULL, '2025-05-24 15:31:30.919629+00', '2025-05-30 10:36:03.190794+00', 80),
	('e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal Unit', NULL, '2025-05-24 15:34:16.907485+00', '2025-05-30 10:36:03.190794+00', 90),
	('20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', NULL, '2025-05-27 15:49:56.650867+00', '2025-05-30 10:36:03.190794+00', 100);


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at", "sort_order", "color") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 41', true, '2025-05-22 10:30:30.870153+00', '2025-05-28 12:25:54.280198+00', 10, '#CCCCCC'),
	('2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'NICU', true, '2025-05-24 12:21:01.329031+00', '2025-05-30 10:35:46.86368+00', 0, '#CCCCCC'),
	('6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 27', true, '2025-05-24 15:04:56.615271+00', '2025-05-30 10:35:46.86368+00', 10, '#CCCCCC'),
	('9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 30 (HCU)', true, '2025-05-24 15:05:26.651408+00', '2025-05-30 10:35:46.86368+00', 30, '#CCCCCC'),
	('c24a3784-6a06-469f-a764-49621f2d88d3', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 31', true, '2025-05-24 15:05:37.494475+00', '2025-05-30 10:35:46.86368+00', 40, '#CCCCCC'),
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', true, '2025-05-22 10:41:18.749919+00', '2025-05-30 10:36:52.347554+00', 50, '#CCCCCC'),
	('8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'IAU', false, '2025-05-24 15:05:46.603744+00', '2025-05-30 10:37:08.411942+00', 140, '#CCCCCC'),
	('a8d3be01-4d46-41c1-b304-ab98610847e7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Vasular Studies', true, '2025-05-24 15:06:04.488647+00', '2025-05-30 10:37:13.256208+00', 160, '#CCCCCC'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 40', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 20, '#CCCCCC'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Library', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 30, '#CCCCCC'),
	('9056ee14-242b-4208-a87d-fc59d24d442c', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Pathology Lab', false, '2025-05-24 12:20:41.049859+00', '2025-05-28 09:40:45.973966+00', 70, '#CCCCCC'),
	('fa9e4d42-8282-42f8-bfd4-87691e20c7ed', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Ward', false, '2025-05-24 15:05:14.044021+00', '2025-05-28 09:40:45.973966+00', 110, '#CCCCCC'),
	('6dc82d06-d4d2-4824-9a83-d89b583b7554', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'SDEC', false, '2025-05-24 15:05:53.620867+00', '2025-05-28 09:40:45.973966+00', 150, '#CCCCCC'),
	('42c2b3ab-f68d-429c-9675-3c79ff0ed222', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Ultrasound', false, '2025-05-24 15:07:04.431723+00', '2025-05-28 09:40:45.973966+00', 200, '#CCCCCC'),
	('35c73844-b511-423e-996c-5328ef21fedd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Clinics A-F', false, '2025-05-24 15:07:14.550747+00', '2025-05-28 09:40:45.973966+00', 210, '#CCCCCC'),
	('7295def1-1827-46dc-a443-a7aa7bf85b52', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Yellow Suite', false, '2025-05-24 15:07:27.863388+00', '2025-05-28 09:40:45.973966+00', 220, '#CCCCCC'),
	('f7c99832-60d1-42ee-8d35-0620a38f1e5d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Blue Suite', false, '2025-05-24 15:07:36.0704+00', '2025-05-28 09:40:45.973966+00', 230, '#CCCCCC'),
	('465893b5-6ab8-4776-bdbd-fd3c608ab966', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Swan Room', false, '2025-05-24 15:07:48.317926+00', '2025-05-28 09:40:45.973966+00', 240, '#CCCCCC'),
	('ac2333d2-0b37-4924-a039-478caf702fbd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s O+A', false, '2025-05-24 15:08:31.112268+00', '2025-05-28 09:40:45.973966+00', 260, '#CCCCCC'),
	('7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Day Surgery', false, '2025-05-24 15:09:06.573728+00', '2025-05-28 09:40:45.973966+00', 270, '#CCCCCC'),
	('4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Endoscopy Unit', false, '2025-05-24 15:09:18.185641+00', '2025-05-28 09:40:45.973966+00', 280, '#CCCCCC'),
	('f7525622-cd84-4c8c-94bf-b0428008b9c3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Frailty', false, '2025-05-24 15:10:12.266212+00', '2025-05-28 09:40:45.973966+00', 300, '#CCCCCC'),
	('36e599c5-89b2-4d50-b7df-47d5d1959ca4', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Surgical Hub', false, '2025-05-24 15:10:26.062318+00', '2025-05-28 09:40:45.973966+00', 310, '#CCCCCC'),
	('19b02bca-1dc6-4d00-b04d-a7e141a04870', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Plaster Room', false, '2025-05-24 15:10:32.921441+00', '2025-05-28 09:40:45.973966+00', 320, '#CCCCCC'),
	('76753b4b-ae1e-4477-a042-8deaab558e7b', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Discharge Lounge', false, '2025-05-24 15:11:40.525042+00', '2025-05-28 09:40:45.973966+00', 340, '#CCCCCC'),
	('0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 44', false, '2025-05-24 15:11:55.713923+00', '2025-05-28 09:40:45.973966+00', 360, '#CCCCCC'),
	('569e9211-d394-4e93-ba3e-34ad20d98af4', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 45', false, '2025-05-24 15:12:01.01766+00', '2025-05-28 09:40:45.973966+00', 370, '#CCCCCC'),
	('0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 46', false, '2025-05-24 15:12:07.981632+00', '2025-05-28 09:40:45.973966+00', 380, '#CCCCCC'),
	('99d8db21-2c14-4f8f-8e54-54fc81004997', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Rose Cottage', false, '2025-05-24 15:12:49.940045+00', '2025-05-28 09:40:45.973966+00', 390, '#CCCCCC'),
	('87a21a43-fe29-448f-9c08-b4d94226ad3f', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Infection Control', false, '2025-05-24 15:13:12.738948+00', '2025-05-28 09:40:45.973966+00', 400, '#CCCCCC'),
	('60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Switch', false, '2025-05-24 15:13:28.133871+00', '2025-05-28 09:40:45.973966+00', 410, '#CCCCCC'),
	('c06cd3c4-8993-4e7b-b198-a7fda4ede658', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Estates Management', false, '2025-05-24 15:13:37.481503+00', '2025-05-28 09:40:45.973966+00', 420, '#CCCCCC'),
	('23199491-fe75-4c33-9cc8-1c86070cf0d1', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Triage', false, '2025-05-24 15:15:20.429518+00', '2025-05-28 09:40:45.973966+00', 450, '#CCCCCC'),
	('c0a07de6-b201-441b-a1fb-2b2ae9a95ac1', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Reception', false, '2025-05-24 15:16:21.942089+00', '2025-05-28 09:40:45.973966+00', 460, '#CCCCCC'),
	('bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Transfusion', false, '2025-05-24 15:20:33.127806+00', '2025-05-28 09:40:45.973966+00', 470, '#CCCCCC'),
	('969a27a7-f5e5-4c23-b018-128aa2000b97', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Bed Store', false, '2025-05-24 15:21:21.166917+00', '2025-05-28 09:40:45.973966+00', 480, '#CCCCCC'),
	('5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Mattress Store', false, '2025-05-24 15:21:31.144781+00', '2025-05-28 09:40:45.973966+00', 490, '#CCCCCC'),
	('9dae2f86-2058-4c9c-a428-76f5648553d3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'North Theatres', false, '2025-05-24 15:24:43.214387+00', '2025-05-28 09:40:45.973966+00', 500, '#CCCCCC'),
	('07e2b454-88ee-4d6a-9d75-a6ffa39bd241', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'South Theatres', false, '2025-05-24 15:24:51.854136+00', '2025-05-28 09:40:45.973966+00', 510, '#CCCCCC'),
	('d82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'MRI', false, '2025-05-24 15:25:16.973586+00', '2025-05-28 09:40:45.973966+00', 530, '#CCCCCC'),
	('df3d8d2a-dee5-4a21-a362-401236a2a1cb', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Pharmacy', false, '2025-05-24 15:30:28.871857+00', '2025-05-28 09:40:45.973966+00', 540, '#CCCCCC'),
	('943915e4-6818-4890-b395-a8272718eaf7', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford One', false, '2025-05-24 15:31:43.707094+00', '2025-05-28 09:40:45.973966+00', 550, '#CCCCCC'),
	('0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Two', false, '2025-05-24 15:31:53.020936+00', '2025-05-28 09:40:45.973966+00', 560, '#CCCCCC'),
	('1cac53b0-f370-4a13-95ca-f4cfd85dd197', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Ground', false, '2025-05-24 15:32:00.795352+00', '2025-05-28 09:40:45.973966+00', 570, '#CCCCCC'),
	('55f54692-d1ee-4047-bace-ff31744d2bc7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'FM Corridor', false, '2025-05-24 15:32:36.1272+00', '2025-05-28 09:40:45.973966+00', 580, '#CCCCCC'),
	('270df887-a13f-4004-a58d-9cec125b8da1', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Kitchens', false, '2025-05-24 15:32:43.567186+00', '2025-05-28 09:40:45.973966+00', 590, '#CCCCCC'),
	('06582332-0637-4d1a-b86e-876afe0bdc98', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Laundry', false, '2025-05-24 15:33:51.477397+00', '2025-05-28 09:40:45.973966+00', 600, '#CCCCCC'),
	('bf03ffcf-98d7-440e-adc1-5081e161c42d', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'I.T.', false, '2025-05-24 15:33:57.806509+00', '2025-05-28 09:40:45.973966+00', 610, '#CCCCCC'),
	('2368699a-6de0-45a9-ae25-dad26160cada', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Porters Lodge', false, '2025-05-24 15:34:07.683358+00', '2025-05-28 09:40:45.973966+00', 620, '#CCCCCC'),
	('ccb6bf8f-275c-4d24-8907-09b97cbe0eea', 'e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal', false, '2025-05-24 15:34:28.590837+00', '2025-05-28 09:40:45.973966+00', 630, '#CCCCCC'),
	('4c0821a2-dba8-48fe-9b8d-1c1ed6f8edea', '20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', false, '2025-05-27 15:50:07.946454+00', '2025-05-28 09:40:45.973966+00', 640, '#CCCCCC'),
	('1ae5c936-b74c-453e-a614-42b983416e40', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 43', true, '2025-05-24 15:11:49.971178+00', '2025-05-28 11:48:51.366161+00', 0, '#CCCCCC'),
	('3aa17398-7823-45ae-b76c-9b30d8509ce1', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 42', false, '2025-05-24 15:11:16.394196+00', '2025-05-28 12:25:57.780742+00', 10, '#CCCCCC'),
	('acb46743-a8c8-4cf5-bc85-4b9480f1862e', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Stores', false, '2025-05-29 08:52:15.626457+00', '2025-05-29 08:52:15.626457+00', 0, '#CCCCCC'),
	('571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Womens Health', true, '2025-05-24 15:14:53.225063+00', '2025-05-30 10:35:46.86368+00', 20, '#CCCCCC'),
	('dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s Unit', false, '2025-05-24 15:08:15.838239+00', '2025-05-30 10:36:42.972929+00', 0, '#CCCCCC'),
	('1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'A+E (ED)', false, '2025-05-24 15:06:24.428146+00', '2025-06-05 05:47:42.426275+00', 170, '#29c7b4'),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-06-05 05:59:25.380049+00', 10, '#e1c84c'),
	('f9d3bbce-8644-4075-8b80-457777f6d16c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Ground Floor', false, '2025-05-24 15:06:39.563069+00', '2025-06-05 06:09:41.18236+00', 180, '#bd2e73'),
	('8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Lower Ground Floor', false, '2025-05-24 15:06:52.499906+00', '2025-06-05 06:10:37.909591+00', 190, '#bd2e73'),
	('5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'CT Scan', false, '2025-05-24 15:25:11.218374+00', '2025-06-05 06:11:50.78881+00', 520, '#bd2e73'),
	('c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'POU', false, '2025-05-24 15:09:37.760662+00', '2025-06-11 11:35:19.925142+00', 290, '#CCCCCC'),
	('a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'CDS (Acorn Birth Centre)', true, '2025-05-24 15:14:21.560252+00', '2025-06-11 13:42:08.798467+00', 430, '#CCCCCC');


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id", "porter_type", "availability_pattern", "contracted_hours_start", "contracted_hours_end") VALUES
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'Martin', 'Smith', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-05-22 16:38:43.142566+00', NULL, 'shift', NULL, NULL, NULL),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'Martin', 'Fearon', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-05-22 16:38:53.581199+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'shift', NULL, NULL, NULL),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'Chris', 'Chrombie', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-05-22 16:39:03.319212+00', NULL, 'shift', NULL, NULL, NULL),
	('a9d969e3-d449-4005-a679-f63be07c6872', 'Luke', 'Clements', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-05-22 16:39:16.282662+00', NULL, 'shift', NULL, NULL, NULL),
	('6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', 'KG', 'Porter', 'porter', '2025-05-28 15:38:38.608871+00', '2025-05-30 16:20:37.92001+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('e9cf3a23-c94a-409b-aa71-d42602e54068', 'MP', 'Porter', 'porter', '2025-05-28 15:38:29.329131+00', '2025-05-30 16:21:01.802578+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('f304fa99-8e00-48d0-a616-d156b0f7484d', 'CW', 'Porter', 'porter', '2025-05-24 15:29:00.080381+00', '2025-05-30 17:10:15.855945+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('4fb21c6f-2f5b-4f6e-b727-239a3391092a', 'EA', 'Porter', 'porter', '2025-05-24 15:29:10.541023+00', '2025-05-30 17:10:43.050862+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'GB', 'Porter', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-30 17:11:04.72929+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('12055968-78d3-4404-a05f-10e039217936', 'MB', 'Porter', 'porter', '2025-05-24 15:35:19.897285+00', '2025-05-30 17:13:13.113785+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('050fa6e6-477b-4f83-aae4-3e13c954ca6a', 'Xray', 'Porter 1', 'porter', '2025-05-28 15:40:45.206052+00', '2025-05-28 15:40:45.206052+00', NULL, 'shift', NULL, NULL, NULL),
	('cb50a5b2-3812-4688-b1f6-ccf0ab7626b6', 'Xray', 'Porter 2', 'porter', '2025-05-28 15:40:56.522945+00', '2025-05-28 15:40:56.522945+00', NULL, 'shift', NULL, NULL, NULL),
	('473eeca1-e8ca-49a7-b2f6-5870dc254dcc', 'No', 'Supervisor', 'supervisor', '2025-05-29 12:56:45.696149+00', '2025-05-29 12:56:45.696149+00', NULL, 'shift', NULL, NULL, NULL),
	('80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', 'RS', 'Porter', 'porter', '2025-05-28 15:38:06.309697+00', '2025-05-30 16:21:29.758058+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('c3052ff8-8339-4e02-b4ed-efee9365e7c2', 'MC', 'Porter', 'porter', '2025-05-28 15:37:56.707711+00', '2025-05-30 16:21:53.673996+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('8b3b3e97-ea54-4c40-884b-04d3d24dbe23', 'JM', 'Porter', 'porter', '2025-05-24 15:46:43.723804+00', '2025-05-30 17:13:40.748857+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('e55b1013-7e79-4e38-913e-c53de591f85c', 'LR', 'Porter', 'porter', '2025-05-24 15:47:03.70938+00', '2025-05-30 17:13:59.97549+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('69766d05-49d7-4e7c-8734-e3dc8949bf91', 'MD', 'Porter', 'porter', '2025-05-24 15:47:22.720752+00', '2025-05-30 17:15:12.217517+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'IS', 'Porter', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-30 17:15:38.338145+00', NULL, 'shift', 'Weekdays - Days', '07:30:00', '15:30:00'),
	('c162858c-9815-43e3-9bcb-0c709bd8eef0', 'SC', 'Porter', 'porter', '2025-05-28 15:39:52.203155+00', '2025-05-31 12:04:48.961386+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('1a21db6c-9a35-48ca-a3b0-06284bec8beb', 'AJ', 'Porter', 'porter', '2025-05-28 15:39:12.414354+00', '2025-05-30 16:22:30.530571+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('04947318-f8a7-4eea-8044-5219c5e907fc', 'CB', 'Porter', 'porter', '2025-05-28 15:36:24.156976+00', '2025-05-31 09:20:58.647194+00', NULL, 'shift', 'Weekends - Days', '11:00:00', '19:00:00'),
	('c965e4e3-e132-43f0-94ce-1b41d33a9f05', 'CR', 'Porter', 'porter', '2025-05-28 15:36:13.899635+00', '2025-05-31 09:21:51.335781+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'LY', 'Porter', 'porter', '2025-05-24 15:28:41.635621+00', '2025-05-31 12:05:19.000564+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', 'DM', 'Porter 1', 'porter', '2025-05-28 15:40:00.100404+00', '2025-05-30 16:19:39.09899+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('2ef290c6-6c61-4d37-be45-d08ae6afc097', 'DM', 'Porter 2', 'porter', '2025-05-28 15:40:14.777056+00', '2025-05-30 16:20:03.887273+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('83fdb588-e638-47ae-b726-51f83a4378c7', 'MS', 'Porter', 'porter', '2025-05-28 15:39:06.096334+00', '2025-05-30 16:23:02.826204+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('4377dd38-cf15-4de2-8347-0461ba6afff5', 'SH', 'Porter', 'porter', '2025-05-28 15:36:45.727912+00', '2025-05-30 16:23:48.277704+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', 'SM', 'Porter', 'porter', '2025-05-28 15:36:52.317877+00', '2025-05-30 16:24:12.341778+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('56d5a952-a958-41c5-aa28-bd42e06720c8', 'MH', 'Porter', 'porter', '2025-05-28 15:37:14.70567+00', '2025-05-30 16:24:43.554717+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b96a6ffa-6f54-4eab-a1c8-5c65dc7223da', 'MW', 'Porter', 'porter', '2025-05-28 15:37:22.975093+00', '2025-05-30 16:25:18.624641+00', NULL, 'shift', 'Weekdays - Days', '06:00:00', '14:00:00'),
	('296edb55-91eb-4d73-aa43-54840cbbf20c', 'AB', 'Porter', 'porter', '2025-05-28 15:37:34.781762+00', '2025-05-30 16:25:58.74326+00', NULL, 'shift', 'Weekdays - Days', '14:00:00', '22:00:00'),
	('1aaab277-ecf2-40dd-a764-eaaf8af7615b', 'At', 'Porter', 'porter', '2025-05-28 15:36:02.205704+00', '2025-05-31 09:22:48.757543+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'JR', 'Porter 2', 'porter', '2025-05-24 15:28:21.287841+00', '2025-05-31 12:06:15.759371+00', NULL, 'relief', 'Weekdays - Days', '14:00:00', '22:00:00'),
	('4e87f01b-5196-47c4-b424-4cfdbe7fb385', 'SC', 'Porter', 'porter', '2025-05-24 15:47:12.658077+00', '2025-05-30 16:28:12.48615+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('8eaa9194-b164-4cb4-a15c-956299ff28c5', 'TB', 'Porter', 'porter', '2025-05-24 15:46:56.110419+00', '2025-05-30 16:28:35.874646+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'LB', 'Porter', 'porter', '2025-05-23 14:15:42.030594+00', '2025-05-31 12:06:29.729689+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'MH', 'Porter 2', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-30 16:29:52.389588+00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('2e74429e-2aab-4bed-a979-6ccbdef74596', 'JR', 'Porter', 'porter', '2025-05-24 15:27:50.974195+00', '2025-05-30 16:30:18.953012+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', 'LS', 'Porter', 'porter', '2025-05-24 15:28:02.842334+00', '2025-05-30 16:59:08.457239+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('bf79faf6-fb3e-4780-841e-63a4a67a5b77', 'NB', 'Porter', 'porter', '2025-05-24 15:28:15.192437+00', '2025-05-30 17:08:00.606828+00', NULL, 'shift', 'Weekdays - Days', '13:00:00', '23:00:00'),
	('7cc268aa-cb72-4320-ba8d-72f77b77dda6', 'DP', 'Porter', 'porter', '2025-05-31 09:36:39.240883+00', '2025-05-31 12:08:25.0057+00', NULL, 'relief', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7c20aec3-bf78-4ef9-b35e-429e41ac739b', 'KS', 'Porter', 'porter', '2025-05-24 15:28:35.013201+00', '2025-05-30 17:09:23.036433+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('2524b1c5-45e1-4f15-bf3b-984354f22cdc', 'PM', 'Porter', 'porter', '2025-05-24 15:28:50.433536+00', '2025-05-30 17:09:45.582369+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('172b28c4-ec0d-4f5c-a859-ff8299ff6243', 'SS', 'Porter', 'porter', '2025-05-31 09:23:33.02904+00', '2025-05-31 09:23:33.02904+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b4bcc3bc-729a-49fe-bf6e-1c30fcac37b3', 'JF', 'Porter', 'porter', '2025-05-31 09:24:06.944074+00', '2025-05-31 09:24:06.944074+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('00e0ca67-f415-45ce-9b11-c3260e9cd58e', 'SB', 'Porter', 'porter', '2025-05-31 09:24:52.480925+00', '2025-05-31 09:24:52.480925+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('63f5c89b-661d-40e5-a810-7fba772d4dc5', 'KB', 'Porter', 'porter', '2025-05-31 09:30:45.461948+00', '2025-05-31 09:30:45.461948+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('d34fa6f7-8d2d-4e20-abda-a77c11554254', 'DF', 'Porter', 'porter', '2025-05-31 09:31:17.530822+00', '2025-05-31 09:31:17.530822+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('5bfb19a8-f295-4e17-b63d-01166fd22acf', 'BC', 'Porter', 'porter', '2025-05-31 09:31:35.719888+00', '2025-05-31 09:31:35.719888+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('4b49d53b-2473-4cc9-9b08-221a6548a93d', 'JM', 'Porter', 'porter', '2025-05-31 09:31:58.967695+00', '2025-05-31 09:31:58.967695+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('af42f57f-1437-4320-b1a2-2b0051948de3', 'AK', 'Porter', 'porter', '2025-05-31 09:32:32.204314+00', '2025-05-31 09:32:32.204314+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('7884c45a-823f-48c9-a4d4-fd2ad426f144', 'SF', 'Porter', 'porter', '2025-05-31 09:35:54.501508+00', '2025-05-31 09:35:54.501508+00', NULL, 'shift', 'Weekdays - Days', '06:00:00', '14:00:00'),
	('4a25cc37-bc1f-4a94-a053-e348412a2432', 'AH', 'Porter', 'porter', '2025-05-31 09:38:15.586949+00', '2025-05-31 09:38:15.586949+00', NULL, 'shift', '4 on 4 off - Days', '13:00:00', '01:00:00'),
	('6c6184fe-7e99-4fc0-a906-ace0a021f160', 'GM', 'Porter', 'porter', '2025-05-31 09:38:54.952643+00', '2025-05-31 09:38:54.952643+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('3316eda6-d5f5-445f-8721-b8c42e18d89c', 'AC', 'Porter', 'porter', '2025-05-31 09:39:31.25173+00', '2025-05-31 09:39:31.25173+00', NULL, 'shift', 'Weekdays - Days', '14:00:00', '01:00:00'),
	('78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', 'MK', 'Porter', 'porter', '2025-05-24 15:28:08.999647+00', '2025-05-31 12:05:14.813613+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('aeac1145-0b87-403a-81db-72b516a9fe15', 'DK', 'Porter', 'porter', '2025-05-31 09:42:05.947895+00', '2025-05-31 09:42:05.947895+00', NULL, 'shift', 'Weekends - Days', '08:00:00', '20:00:00'),
	('c30cc891-1722-404f-9b84-14ffcee8d93f', 'SL', 'Porter', 'porter', '2025-05-31 09:44:38.837174+00', '2025-05-31 09:44:38.837174+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7baf82c3-c592-43fa-aac0-b53fbd8e9a1d', 'SR', 'Porter', 'porter', '2025-05-31 11:41:00.64654+00', '2025-05-31 11:41:00.64654+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('0655269c-b297-42e7-bdec-afb55cdee4d2', 'ML', 'Porter', 'porter', '2025-05-31 11:42:20.747495+00', '2025-05-31 11:42:20.747495+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('74da0ff0-44aa-4fd5-a464-d25e45bea636', 'JG', 'Porter', 'porter', '2025-05-31 11:43:39.963596+00', '2025-05-31 11:43:39.963596+00', NULL, 'shift', 'Weekdays - Days', '08:30:00', '16:30:00'),
	('0689dc61-6dcd-413d-a9f8-579fdc716757', 'EC', 'Porter', 'porter', '2025-05-31 11:50:01.961067+00', '2025-05-31 11:50:01.961067+00', NULL, 'shift', 'Weekdays - Days', '10:00:00', '18:00:00'),
	('df3f3a6d-23b5-4970-9ae0-47d458b84dd3', 'PH', 'Porter', 'porter', '2025-05-31 11:50:26.154544+00', '2025-05-31 11:50:26.154544+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('534e6bda-2978-47cd-aacc-f1bd3f94e981', 'KT', 'Porter', 'porter', '2025-05-31 11:50:51.022783+00', '2025-05-31 11:50:51.022783+00', NULL, 'shift', 'Weekdays - Days', '10:00:00', '18:00:00'),
	('8daf3b6b-4e59-4445-ac27-397d1bc7854d', 'CH', 'Porter', 'porter', '2025-05-31 11:52:25.441626+00', '2025-05-31 11:52:25.441626+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('c3579d99-b97e-4019-b37a-f63515fe3ca4', 'PB', 'Porter', 'porter', '2025-05-31 11:52:53.118104+00', '2025-05-31 11:52:53.118104+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', 'RF', 'Porter', 'porter', '2025-05-31 11:53:07.6934+00', '2025-05-31 11:53:07.6934+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('ac5427be-ea01-4f42-9c46-17e2f089dee8', 'AG', 'Porter', 'porter', '2025-05-31 11:53:20.904075+00', '2025-05-31 11:53:20.904075+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7a905342-f7d6-4105-b56f-d922e86dbbd9', 'NB', 'Porter', 'porter', '2025-05-31 11:53:50.689917+00', '2025-05-31 11:53:50.689917+00', NULL, 'shift', 'Weekdays - Days', '08:30:00', '16:30:00'),
	('2fe13155-0425-4634-b42a-04380ff73ad1', 'PF', 'Porter', 'porter', '2025-05-31 11:54:42.540751+00', '2025-05-31 11:54:42.540751+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('ccac560c-a3ad-4517-895d-86870e9ad00a', 'AF', 'Porter', 'porter', '2025-05-31 12:05:54.898527+00', '2025-05-31 12:05:54.898527+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('6e772f6a-e4e8-422a-b21b-ff677b625471', 'SO', 'Porter', 'porter', '2025-05-31 12:07:12.641402+00', '2025-05-31 12:07:12.641402+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('a55d23b5-154f-425b-a0b3-11d5e3ef5ffd', 'MR', 'Porter', 'porter', '2025-05-31 12:09:18.007059+00', '2025-05-31 12:09:18.007059+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('1f1e61c3-848c-441c-8b89-8a85e16285df', 'DS', 'Porter', 'porter', '2025-05-31 12:09:48.190182+00', '2025-05-31 12:09:48.190182+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('b30280c2-aecc-4953-a1df-5f703bce4772', 'JN', 'Porter', 'porter', '2025-06-02 17:25:09.547001+00', '2025-06-02 17:25:09.547001+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('85d80fef-9a4b-4878-b647-63301e934b51', 'PH', 'Porter 2', 'porter', '2025-06-05 06:28:40.304454+00', '2025-06-05 06:31:09.403628+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00');


--
-- Data for Name: area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_assignments" ("id", "department_id", "porter_id", "start_time", "end_time", "color", "created_at", "updated_at", "shift_type") VALUES
	('1d4a326e-8401-4e31-b1ec-fa810b68fd1a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '20:00:00', '08:00:00', '#4285F4', '2025-05-24 15:42:29.23697+00', '2025-05-26 09:05:32.036362+00', 'week_night'),
	('06213b7c-812e-4f48-a79d-ecbc9a87d30a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '08:00:00', '20:00:00', '#4285F4', '2025-05-24 15:45:03.686512+00', '2025-05-26 09:05:42.619325+00', 'weekend_day'),
	('2100396b-f96d-4a7c-9d1b-006775df4ef7', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:44:23.448158+00', '2025-05-26 09:05:52.579036+00', 'weekend_night'),
	('a2787626-bc01-411b-a2ca-a50d2c63ced6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '08:00:00', '20:00:00', '#4285F4', '2025-05-24 15:30:45.762708+00', '2025-05-26 10:32:42.81672+00', 'week_day'),
	('4030ddba-717e-498d-92fc-cf401ef4d908', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:40:52.51208+00', '2025-05-24 15:40:52.51208+00', 'week_day'),
	('8c1d80d9-68f3-4bc2-a578-5707de26e00f', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-25 09:56:41.356955+00', '2025-05-25 09:56:41.356955+00', 'week_night');


--
-- Data for Name: area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_porter_assignments" ("id", "area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('6da09732-7edb-498b-aa5b-5c006f9b3297', 'a2787626-bc01-411b-a2ca-a50d2c63ced6', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-26 10:32:42.903703+00', '2025-05-26 10:32:42.903703+00');


--
-- Data for Name: default_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_assignments" ("id", "department_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('2f7b79ab-e3fd-4745-9095-633bc97a05cc', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:47.240244+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('62d6ae7f-b3ef-4bd0-ad5a-c4a0ab46c5fa', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:50.992166+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('de8f136e-deeb-494b-bae9-54cf7a4ea5bf', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:14:15.321389+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9ccff924-1281-42ac-b712-7989bfe50c6d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:21:05.371703+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4b07ffe6-9df3-4e93-ba02-ecd8607c65d3', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:21:24.017899+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3a2ff90b-5523-4f5f-848d-3d8989c81981', 'f9d3bbce-8644-4075-8b80-457777f6d16c', 'week_day', '08:00:00', '17:00:00', '#4285F4', '2025-05-28 15:11:59.336598+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('84a7eb2b-66ad-4883-a6ef-e78bedff694a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_night', '20:00:00', '08:00:00', '#4285F4', '2025-05-28 15:13:29.515957+00', '2025-06-04 09:26:36.381246+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d60ea4d0-7c69-412c-9dd1-aad01645e1dc', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'week_day', '08:00:00', '20:00:00', '#4e7a27', '2025-05-28 15:12:39.489353+00', '2025-06-05 04:40:37.251474+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('ed182065-4e96-40cb-9b41-96f7cdebb907', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_night', '20:00:00', '08:00:00', '#c2426f', '2025-05-28 15:20:32.081824+00', '2025-06-05 04:42:46.668777+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('55a9e1d1-b177-4fc8-ba8d-a1483bd58e40', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'week_day', '11:00:00', '18:00:00', '#e4cd3a', '2025-05-28 15:05:10.786766+00', '2025-06-05 04:44:53.523961+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:12:06.807373+00', '2025-06-05 06:32:30.11224+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('d71c6999-f5ca-4108-a2e0-21c4afc008f5', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_day', '08:00:00', '20:00:00', '#5ac445', '2025-05-28 15:07:17.30595+00', '2025-06-05 06:35:11.520522+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: default_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_porter_assignments" ("id", "default_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('62d587a8-3897-45bc-98b4-71532ddfd26b', '3a2ff90b-5523-4f5f-848d-3d8989c81981', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-05-31 15:25:00.501678+00', '2025-05-31 15:25:00.501678+00'),
	('3f7c91e8-c24c-4af2-9515-7380f07e5ff1', '3a2ff90b-5523-4f5f-848d-3d8989c81981', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-05-31 15:25:00.5513+00', '2025-05-31 15:25:00.5513+00'),
	('5ae0a276-53f6-4ec0-84ee-86eb720f25f0', '84a7eb2b-66ad-4883-a6ef-e78bedff694a', '56d5a952-a958-41c5-aa28-bd42e06720c8', '20:00:00', '08:00:00', '2025-06-04 09:26:36.482709+00', '2025-06-04 09:26:36.482709+00'),
	('0b2607be-1a5c-41d8-92db-f06595a0868a', 'd60ea4d0-7c69-412c-9dd1-aad01645e1dc', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-05-31 15:30:09.094954+00', '2025-06-05 04:40:37.332478+00'),
	('eb3d4131-0bf3-4c12-9998-93f0a6238b32', 'd60ea4d0-7c69-412c-9dd1-aad01645e1dc', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-05-31 15:30:09.146339+00', '2025-06-05 04:40:37.40642+00'),
	('2d18d5e3-47e3-4508-a290-a0297fe1ba86', 'ed182065-4e96-40cb-9b41-96f7cdebb907', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '20:00:00', '08:00:00', '2025-06-05 04:42:46.752239+00', '2025-06-05 04:42:46.752239+00'),
	('dc65a01c-287b-4145-84a6-331237a72f3a', '5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-05-31 15:26:32.100352+00', '2025-06-05 06:32:30.18014+00'),
	('eccbf4fc-ffaf-42c6-812b-beaf1d91173b', '5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-05-31 15:26:32.16221+00', '2025-06-05 06:32:30.259571+00'),
	('98f3579a-6cc4-4c21-8cf3-076f1be56d6e', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-05-31 15:33:24.32966+00', '2025-06-05 06:35:11.59285+00'),
	('5f055cba-c4df-48f2-9298-3896a360e4a2', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-01 18:40:20.05806+00', '2025-06-05 06:35:11.661894+00');


--
-- Data for Name: support_services; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_services" ("id", "name", "description", "is_active", "created_at", "updated_at") VALUES
	('30c5c045-a442-4ec8-b285-c7bc010f4d83', 'Laundry', 'Porter support for laundry services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ce940139-6ae7-49de-a62a-0d6ba9397928', 'Post', 'Internal mail and document delivery', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('0b5c7062-1285-4427-8387-b1b4e14eedc9', 'Pharmacy', 'Medication delivery service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'District Drivers', 'External transport services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('7cfa1ddf-61b0-489e-ad23-b924cf995419', 'Adhoc', 'Miscellaneous tasks requiring porter assistance', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('26c0891b-56c0-4346-8d53-de906aaa64c2', 'Medical Records', 'Patient records transport service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'External Waste', NULL, true, '2025-05-28 15:08:35.337525+00', '2025-05-28 15:08:35.337525+00');


--
-- Data for Name: default_service_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_assignments" ("id", "service_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('ce4b641d-619d-4c1b-8c68-d9d850306492', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:14:07.575453+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'week_day', '07:00:00', '15:00:00', '#c8a76f', '2025-05-28 15:08:50.364355+00', '2025-06-02 17:19:07.627643+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'week_day', '08:30:00', '17:00:00', '#4285F4', '2025-05-28 15:07:57.826093+00', '2025-06-04 11:44:12.610082+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('557671ae-71a7-41f5-bbf7-7d74413e7c9a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', 'week_day', '15:00:00', '20:00:00', '#4285F4', '2025-05-28 15:07:40.45798+00', '2025-06-05 04:48:38.545355+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', 'ce940139-6ae7-49de-a62a-0d6ba9397928', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:33.377391+00', '2025-06-05 04:52:11.826499+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '26c0891b-56c0-4346-8d53-de906aaa64c2', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 15:07:46.235606+00', '2025-06-05 04:54:54.45835+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '7cfa1ddf-61b0-489e-ad23-b924cf995419', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:07:52.088351+00', '2025-06-05 04:55:58.87026+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('aa1a61d1-e538-415a-a89d-9f568fc92adb', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:05:23.573715+00', '2025-06-05 06:38:35.151511+00', 2, 2, 2, 2, 2, 2, 2, 2);


--
-- Data for Name: default_service_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_porter_assignments" ("id", "default_service_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('a8f08037-c45c-4692-bc79-171d7182f8f7', '57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-02 17:19:07.709693+00', '2025-06-02 17:19:07.709693+00'),
	('f3fe847c-e319-4ea8-a4b1-ea0dae937da0', '57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-02 17:19:07.771004+00', '2025-06-02 17:19:07.771004+00'),
	('8317bd19-3ac9-4b0e-a200-7f8d201fa630', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-01 18:54:01.502989+00', '2025-06-04 11:44:12.678498+00'),
	('6dc87b69-0871-447f-a0c0-75cac448c449', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-01 18:54:01.54246+00', '2025-06-04 11:44:12.74195+00'),
	('0c25f6c0-19f1-4288-97cf-9b28212a9e0a', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-01 18:54:01.589009+00', '2025-06-04 11:44:12.814671+00'),
	('4578c334-21c4-4427-9569-cd251016820e', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-01 18:54:01.632847+00', '2025-06-04 11:44:12.882056+00'),
	('7e00cfbe-d3b6-412e-b728-504a3256d0b6', '557671ae-71a7-41f5-bbf7-7d74413e7c9a', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 04:48:38.636972+00', '2025-06-05 04:48:38.636972+00'),
	('97e2b825-a753-49e5-add4-d506434080bc', '6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 04:51:12.878995+00', '2025-06-05 04:52:11.910335+00'),
	('b3caa690-521b-45ed-8ee4-2813865629a3', '6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 04:52:11.962278+00', '2025-06-05 04:52:11.962278+00'),
	('d978a8f5-de5c-4e44-b4ef-a249928c490b', '55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 04:53:42.467874+00', '2025-06-05 04:54:54.506555+00'),
	('9ad8f215-ae55-4cd6-a029-7da1809341bc', '55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 04:54:25.507056+00', '2025-06-05 04:54:54.573688+00'),
	('ae63ea97-d6dd-4acc-8aaf-d41dd798caca', '55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 04:54:54.615355+00', '2025-06-05 04:54:54.615355+00'),
	('44d34895-d3e5-4a87-b845-67f8aff12f37', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-02 17:22:13.804891+00', '2025-06-05 04:55:58.964112+00'),
	('d8f9e89a-3736-4aec-a698-f7a19218362a', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 04:55:59.028775+00', '2025-06-05 04:55:59.028775+00'),
	('bcd0f2a0-34ac-43f6-a860-3224f40d60ee', 'aa1a61d1-e538-415a-a89d-9f568fc92adb', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-05 06:38:35.255003+00', '2025-06-05 06:38:35.255003+00'),
	('8b0fad05-a563-4a4d-ad55-29523c97ac1f', 'aa1a61d1-e538-415a-a89d-9f568fc92adb', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-05 06:38:35.331861+00', '2025-06-05 06:38:35.331861+00');


--
-- Data for Name: task_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_types" ("id", "name", "description", "created_at", "updated_at") VALUES
	('bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Equipment Transfer', 'Tasks related to moving equipment between departments', '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('b864ed57-5547-404e-9459-1641a030974e', 'Asset Delivery', NULL, '2025-05-22 11:24:42.733351+00', '2025-05-22 11:24:42.733351+00'),
	('a97d8a74-0e16-4e1f-908e-96e935d91002', 'Gases', NULL, '2025-05-22 11:24:51.97167+00', '2025-05-24 15:17:57.977482+00'),
	('f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Patient Transfer', 'Tasks related to moving patients between departments', '2025-05-22 11:12:54.89695+00', '2025-05-24 15:19:11.095037+00'),
	('fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Samples', 'Tasks related to delivering specimens to labs', '2025-05-22 11:12:54.89695+00', '2025-05-24 15:19:25.231715+00'),
	('9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Transfusion', NULL, '2025-05-24 15:23:22.494506+00', '2025-05-24 15:23:22.494506+00'),
	('e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Asset Removal', NULL, '2025-05-24 15:26:50.239275+00', '2025-05-24 15:26:50.239275+00');


--
-- Data for Name: task_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_items" ("id", "task_type_id", "name", "description", "created_at", "updated_at", "is_regular") VALUES
	('e6068d5d-4bc5-4358-8bae-ed23759dc733', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen F Size', NULL, '2025-05-22 11:25:09.159861+00', '2025-05-22 11:25:09.159861+00', false),
	('8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed (Complete)', NULL, '2025-05-22 12:00:44.450407+00', '2025-05-22 12:00:44.450407+00', false),
	('a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed Frame', NULL, '2025-05-22 12:00:52.076144+00', '2025-05-22 12:00:52.076144+00', false),
	('93150478-e3b7-4315-bfb2-8f44a78b2f77', 'b864ed57-5547-404e-9459-1641a030974e', 'Mattress', NULL, '2025-05-24 15:17:23.893487+00', '2025-05-24 15:17:23.893487+00', false),
	('532b14f0-042a-4ddf-bc7d-cb95ff298132', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Incubator', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:17:40.681145+00', false),
	('f18bf0ce-835e-4d9d-92d0-119222a56f5e', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen D Size', NULL, '2025-05-24 15:18:21.251002+00', '2025-05-24 15:18:21.251002+00', false),
	('377506db-7bf7-44e8-bc8f-c7c316914579', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Entenox E Size', NULL, '2025-05-24 15:18:39.13243+00', '2025-05-24 15:18:39.13243+00', false),
	('68e8e006-79dc-4d5f-aed0-20755d53403b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Wheelchair', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:56.015534+00', false),
	('934256c2-fbe5-480b-a0ac-897d9d5b9358', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Urine Sample', NULL, '2025-05-24 15:19:41.366895+00', '2025-05-24 15:19:41.366895+00', false),
	('5c0c9e25-ae34-4872-8696-4c4ce6e76112', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Multiple Samples', NULL, '2025-05-24 15:19:53.083235+00', '2025-05-24 15:19:53.083235+00', false),
	('e5e84800-eb11-4889-bb97-39ea75ef5190', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Blood', NULL, '2025-05-24 15:23:49.29882+00', '2025-05-24 15:23:49.29882+00', false),
	('ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Albumen', NULL, '2025-05-24 15:23:58.062632+00', '2025-05-24 15:23:58.062632+00', false),
	('b55609c2-9be4-4851-ad2c-dfc199795298', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Platelets', NULL, '2025-05-24 15:24:05.948941+00', '2025-05-24 15:24:05.948941+00', false),
	('b8fed973-ab36-4d31-801a-7ebbde95413a', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed (Complete)', NULL, '2025-05-24 15:27:01.862194+00', '2025-05-24 15:27:01.862194+00', false),
	('81e0d17c-740a-4a00-9727-81d222f96234', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed Frame', NULL, '2025-05-24 15:27:10.580403+00', '2025-05-24 15:27:10.580403+00', false),
	('deab62e1-ae79-4f77-ab65-0a04c1f040a1', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Mattress', NULL, '2025-05-24 15:27:17.680461+00', '2025-05-24 15:27:17.680461+00', false),
	('1933a5d4-e02d-4301-b580-a0fdbdbfb21d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Walk', NULL, '2025-05-25 09:51:59.07475+00', '2025-05-25 09:51:59.07475+00', false),
	('be835d6f-62c6-48bf-ae5f-5257e097349b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Rose Cottage', NULL, '2025-05-27 15:50:47.505753+00', '2025-05-27 15:50:47.505753+00', false),
	('5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen E Size', NULL, '2025-05-24 15:18:10.625096+00', '2025-05-29 17:55:20.230293+00', true),
	('dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Blood Sample', NULL, '2025-05-22 11:12:54.89695+00', '2025-06-05 06:40:27.068944+00', true),
	('5c269ddd-7abd-4d10-a0b3-d93fccb4f6de', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Trolly', NULL, '2025-05-24 15:19:02.302787+00', '2025-06-11 16:30:55.48086+00', false),
	('14446938-25cd-4655-ad84-dbb7db871f28', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Bed', NULL, '2025-05-22 11:12:54.89695+00', '2025-06-11 16:30:55.5597+00', true);


--
-- Data for Name: department_task_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."department_task_assignments" ("id", "department_id", "task_type_id", "task_item_id", "created_at") VALUES
	('a409134d-ff8d-4669-b298-caee04c21a86', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 14:50:26.865921+00'),
	('b1d27130-5806-41f1-9cec-c47670b512d5', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 14:50:51.305825+00'),
	('da1128e3-7ecf-4684-b83c-e87316c57279', '9056ee14-242b-4208-a87d-fc59d24d442c', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '2025-06-11 14:51:16.895449+00'),
	('b2dd6756-f772-45b2-904b-69c96e6544ef', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '2025-06-11 14:51:32.185514+00'),
	('a839ea6f-cb73-4a59-bcfe-68173dfa1e88', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:51:48.062865+00'),
	('0ac90389-47f1-4995-bd19-2acd04864682', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:00.563566+00'),
	('aeffb87e-b1cf-4f24-863b-9779b39050c8', 'a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:15.17909+00'),
	('1707f30b-e1e5-4060-b8d5-0055126a3a69', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:22.692509+00'),
	('d21c118b-113d-4f8a-acec-d177075a0073', '23199491-fe75-4c33-9cc8-1c86070cf0d1', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:34.421428+00'),
	('c89832ad-c3f9-4a6f-8704-9c52ed83fb00', 'ac2333d2-0b37-4924-a039-478caf702fbd', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:16:43.436747+00'),
	('1a08c8a5-76fc-42ec-8694-5edb6d72d6fb', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 15:17:10.751269+00'),
	('fce1f7e1-ed1b-472c-9563-8c1b66719e22', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:17:33.118989+00'),
	('222e730b-6d15-45d6-bc8c-a1268e2df90f', '4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '5c0c9e25-ae34-4872-8696-4c4ce6e76112', '2025-06-11 15:17:42.772506+00'),
	('1ec876d6-011b-48b6-8c43-15890f281d4c', '831035d1-93e9-4683-af25-b40c2332b2fe', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:17:58.422893+00'),
	('7098334f-2f5f-49c8-8beb-c8e5f585ec81', 'c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:18:11.992868+00'),
	('d4832e21-9714-4c62-a001-5537258ae7f5', 'a8d3be01-4d46-41c1-b304-ab98610847e7', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '68e8e006-79dc-4d5f-aed0-20755d53403b', '2025-06-11 15:18:27.330724+00'),
	('24dbc56d-444b-4c3f-a94c-8ebcf231924e', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 15:19:01.298706+00');


--
-- Data for Name: porter_absences; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."porter_absences" ("id", "porter_id", "absence_type", "start_date", "end_date", "created_at", "updated_at", "notes") VALUES
	('39946668-fb64-46dc-ade9-3e4e63482372', '7884c45a-823f-48c9-a4d4-fd2ad426f144', 'illness', '2025-06-03', '2025-06-10', '2025-06-03 15:55:02.824141+00', '2025-06-03 15:55:02.824141+00', ''),
	('4fb85cec-3dd5-445f-a301-21e82d5867dc', '2e74429e-2aab-4bed-a979-6ccbdef74596', 'annual_leave', '2025-06-03', '2025-06-05', '2025-06-03 16:19:50.491773+00', '2025-06-03 16:19:50.491773+00', 'Test'),
	('cd529b26-bdbf-4d1a-bd45-bb39862f6f8a', '296edb55-91eb-4d73-aa43-54840cbbf20c', 'annual_leave', '2025-06-03', '2025-06-06', '2025-06-03 16:46:24.129961+00', '2025-06-03 16:46:24.129961+00', 'Test 2'),
	('0269ce02-1315-42eb-843c-102a6ae52d14', '3316eda6-d5f5-445f-8721-b8c42e18d89c', 'illness', '2025-06-03', '2025-06-04', '2025-06-03 17:11:47.779144+00', '2025-06-03 17:11:47.779144+00', ''),
	('5b3ce846-6af6-4dfc-acf1-acd93b53573b', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', 'illness', '2025-06-04', '2025-06-05', '2025-06-03 17:46:24.707979+00', '2025-06-03 17:46:24.707979+00', '');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at") VALUES
	('7700370b-ea09-4d37-ae48-5226c13be7cc', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-06-06 09:27:17+00', NULL, true, '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('49577c3f-f64f-4d62-ac20-e7ead42bed6e', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-06-07 09:27:17+00', NULL, true, '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('5cd73045-8fb5-42dc-bacd-20408a628e94', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-11 05:53:15+00', NULL, true, '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('96d2f593-03bc-43f0-8f0b-22fc795e4882', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-03 18:02:04+00', '2025-06-04 10:52:54.464+00', false, '2025-06-03 18:02:04.950622+00', '2025-06-04 10:52:54.600102+00'),
	('7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-04 09:34:04+00', '2025-06-04 10:52:58.264+00', false, '2025-06-04 09:34:04.700211+00', '2025-06-04 10:52:58.405287+00'),
	('d10c030e-fe11-4370-9062-4a202cfc9e3b', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-04 10:52:39+00', '2025-06-04 10:53:02.862+00', false, '2025-06-04 10:52:39.201116+00', '2025-06-04 10:53:02.997487+00'),
	('fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-06-04 10:53:17+00', '2025-06-04 11:16:21.484+00', false, '2025-06-04 10:53:17.880612+00', '2025-06-04 11:16:21.599852+00'),
	('ca8fe410-afa5-4a0a-83c0-bb2195fec54a', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'week_day', '2025-06-04 11:16:25+00', '2025-06-04 11:29:43.493+00', false, '2025-06-04 11:16:25.652245+00', '2025-06-04 11:29:43.598083+00'),
	('7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-04 11:29:48+00', '2025-06-04 11:43:58.015+00', false, '2025-06-04 11:29:48.838051+00', '2025-06-04 11:43:58.304726+00'),
	('5b434b59-050e-429b-a95f-c71b9c67772a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-04 11:44:21+00', '2025-06-05 04:30:00.052+00', false, '2025-06-04 11:44:21.654823+00', '2025-06-05 04:30:00.135725+00'),
	('8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-05 04:31:08+00', '2025-06-05 05:49:09.126+00', false, '2025-06-05 04:31:08.353754+00', '2025-06-05 05:49:09.249307+00'),
	('6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-07 05:49:15+00', '2025-06-05 09:27:02.948+00', false, '2025-06-05 08:34:29.808276+00', '2025-06-05 09:27:03.009276+00'),
	('9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-05 05:49:15+00', '2025-06-05 09:27:11.787+00', false, '2025-06-05 05:49:15.231159+00', '2025-06-05 09:27:11.865052+00'),
	('24c2b9c8-bcd0-46d5-9571-c86790690ef5', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-06-05 09:27:17+00', NULL, true, '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('ff1e5da4-37b6-4948-996d-1fadb536844e', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b1daf65d-f3f9-4d97-9311-6b2e0cc48352', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e25ed9c1-66d0-4553-b05f-15dbf59287b1', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a0b12948-5b38-4c2b-ab7f-05e04b4be5ca', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e99eb180-ff1f-4e03-80ab-a59d86659213', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('eed691f5-dfa4-4668-9a37-ba5df75dcbff', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4b8cc5c9-d702-461c-90c8-d619548a3d2c', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('798a5402-e0f2-446c-b529-f8af0ff94ec5', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a75208dd-0645-4a11-95ba-91db0f309f29', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('00580228-aef6-4a3e-810a-55b133a744cc', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4d169aa0-0856-4b3c-aa79-87e81849e34c', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('e836ba2a-4282-4e28-aa19-84708014c0e8', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('343025fe-d3b7-40fb-93c4-eadc7aa29df0', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('727a5cdd-dde1-4d07-bc21-d1257d3e0ebc', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d1eb80f7-de39-43fc-ad28-42287769a913', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('57fb6ae9-116f-4f11-b09a-43d01b7db3eb', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8e34ab35-c94b-463a-8683-71888dbd296f', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('c0ffa4d5-f2dc-4ba2-a8fc-0be7e7179ead', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('71a1acec-4b02-454a-9c58-6768f326fd46', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('61422726-8a8b-4bda-bb63-9cd0da243fcc', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('efd23e9e-e013-49d6-b03d-133da26050f6', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7ab25a5a-c099-4775-b985-16a9bd82556f', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b4be5273-5626-413b-8485-5f90d9dbbedc', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('ecbe4fb0-e2cc-4d6b-af8a-d4e4ef9ae15a', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('69d35f3d-dc55-4637-bfa4-8c65b072a420', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ac14d06d-031b-46ed-a16d-19623ce45fb2', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2560cc45-c53a-43ff-9317-a89fa97540ad', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4f166b1b-e4f7-4c26-a6d8-cb8fc857e972', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f2a42ffb-9313-4e53-a16a-30dd8bb75dc2', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('76538f0c-ef09-41e6-9732-3a112b7b9466', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4460604e-abb1-4558-8d39-18ef86742aa5', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('be7c0cbf-7fd9-431f-bf95-93fbe4ba7652', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0f4a2175-5ca9-4cf6-ad5c-3b6aa85f1d46', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('56e448e4-0b64-400d-9e84-a4be04ea1140', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0d368876-98ee-4695-8e0e-1c909a92eb40', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('b163daf3-3c70-4ca5-9f65-e7e0f968a85f', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3e91d847-564b-4256-9c16-b649115b6f60', '5b434b59-050e-429b-a95f-c71b9c67772a', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cefca01c-ecf2-4dd1-a564-62177144114e', '5b434b59-050e-429b-a95f-c71b9c67772a', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8b4a6a0a-e0ec-436e-97e4-3514a19978b0', '5b434b59-050e-429b-a95f-c71b9c67772a', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c77ac5d8-530d-4dde-a351-7c4b7ac653f0', '5b434b59-050e-429b-a95f-c71b9c67772a', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f24b536b-f902-4f3d-abd9-950288348ab8', '5b434b59-050e-429b-a95f-c71b9c67772a', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('00c28643-671b-4245-a8cd-8ad0edb92785', '5b434b59-050e-429b-a95f-c71b9c67772a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c9655b4c-c5b2-4419-aa00-745e6ff3a121', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8c91c663-d55f-4f33-b2de-45f2e44e586b', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e2e1afe2-1b08-49ed-9158-8de2151fe4ec', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c722b0f9-4041-4fa0-bc54-51f83f878f9b', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1acb4612-742b-4fc6-8f10-63d03d7b3f9c', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('f7cbc17f-9a47-4b5c-beb3-9d6d8e32ec5a', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('24bd2caa-59db-4352-8435-70b8d4f8af7b', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e4cd3a', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('21a04880-ef0f-4e09-8d7e-34dcc558e203', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('616ee323-422e-49ae-b8a3-6b1d3480f315', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('64d3f85d-ea20-498e-bf2b-a7d9b2287789', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('4d7b7eba-a0fb-46d2-b48e-196e312c024b', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#5ac445', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0307af26-f1d2-43d8-9dcc-1e674d08815d', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e4cd3a', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('80902bf8-c1c0-462f-a548-698571aab7d0', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0169c25d-fb19-4aa8-9e2f-e8996a124831', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('497ea3f1-a167-404f-b012-820dadd5b30b', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('ed9b55a5-e780-419a-aa12-d9aa0a5cbb3f', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#5ac445', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('80d837e1-9425-4ae4-8fb4-8c1abef527f7', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e4cd3a', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6d9e0cbf-f841-4b1e-a678-4ea4019e1f0a', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d0a19ae0-831c-40a5-b6d2-4b7d003f2398', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('76c3e096-2f13-4662-ad43-dca9d74628c5', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('ec700602-befa-46f9-95a0-245b38583dd2', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#5ac445', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('63199f12-ef98-4db8-b224-d537f7fb6cd0', '7700370b-ea09-4d37-ae48-5226c13be7cc', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e4cd3a', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1eefdfcf-adf6-4c4d-af81-fb6e45ff2086', '7700370b-ea09-4d37-ae48-5226c13be7cc', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a625074f-bd36-4775-92be-434a0b2a87cb', '7700370b-ea09-4d37-ae48-5226c13be7cc', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('3b74144d-12ec-4ea5-9582-70696ac4781a', '7700370b-ea09-4d37-ae48-5226c13be7cc', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('5bdfa3bb-3797-4c7c-880e-8e506d9fb98c', '7700370b-ea09-4d37-ae48-5226c13be7cc', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#5ac445', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2ac00a13-2f10-4cda-8764-6d8e0734a36a', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e4cd3a', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b1153bca-d2e2-4329-88f9-e7c53453c4f2', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('89711d5c-c7cb-4cba-946e-7bd6a15916b4', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('44b11262-a507-4836-9a30-275758e30444', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('1188f2f9-a4d1-421c-be31-2e7a734e22b1', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#5ac445', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7b10be7a-4205-4895-8be9-2d6b9af81daa', '5cd73045-8fb5-42dc-bacd-20408a628e94', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e4cd3a', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2be16bc3-5bae-4b89-a423-49a90fe564fc', '5cd73045-8fb5-42dc-bacd-20408a628e94', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cd84cb0f-1dd0-4231-96fc-3013fa9f4644', '5cd73045-8fb5-42dc-bacd-20408a628e94', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('76746c80-b29b-46da-9949-e1076256bff6', '5cd73045-8fb5-42dc-bacd-20408a628e94', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('51fa7d37-5dfd-4bc9-a602-0d33d0b19704', '5cd73045-8fb5-42dc-bacd-20408a628e94', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#5ac445', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_porter_assignments" ("id", "shift_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('e35780ad-28de-4c11-ae05-da9cffe76cf5', 'e25ed9c1-66d0-4553-b05f-15dbf59287b1', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('343b0b75-34a6-4bc6-b00f-b2eaadafef75', 'e25ed9c1-66d0-4553-b05f-15dbf59287b1', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('82721344-fa99-423e-bcdc-984c7a932fd8', 'a0b12948-5b38-4c2b-ab7f-05e04b4be5ca', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('bbe3622a-a9b8-41f7-a55c-5e38f092ff78', 'a0b12948-5b38-4c2b-ab7f-05e04b4be5ca', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('39973f5b-2042-4fc2-99ba-bd6143e352ba', 'e99eb180-ff1f-4e03-80ab-a59d86659213', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('6b1566fd-509f-40fd-aa64-a178b43d407c', 'e99eb180-ff1f-4e03-80ab-a59d86659213', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('e972c7a4-157a-4413-b2e2-73c1624dbbfd', 'eed691f5-dfa4-4668-9a37-ba5df75dcbff', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('db9aca5e-d9b7-441f-9894-62dae16a1938', 'eed691f5-dfa4-4668-9a37-ba5df75dcbff', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('ac38e59a-a783-4c6a-bd34-fdf9be83d740', 'b1daf65d-f3f9-4d97-9311-6b2e0cc48352', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '20:00:00', '2025-06-03 18:17:23.301219+00', '2025-06-03 18:17:23.301219+00'),
	('641a5add-e47e-4ef0-864a-766b7430cd27', 'a75208dd-0645-4a11-95ba-91db0f309f29', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('6bb013df-3768-4532-be8b-54226866ef56', 'a75208dd-0645-4a11-95ba-91db0f309f29', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('3fc28b45-208a-4cbb-8927-b7cba1284f0d', '00580228-aef6-4a3e-810a-55b133a744cc', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('6d78c0d8-95df-4eac-8b27-ed7818d273ce', '00580228-aef6-4a3e-810a-55b133a744cc', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('b09b73e9-5bab-4c6c-b84d-00ce91198509', '4d169aa0-0856-4b3c-aa79-87e81849e34c', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('6569ff93-f3a4-493b-93fe-49a91e37a1d8', '4d169aa0-0856-4b3c-aa79-87e81849e34c', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('3b280f4d-a534-4df2-a37f-ce85d6538e74', 'e836ba2a-4282-4e28-aa19-84708014c0e8', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('55b1e436-d17b-44b1-ad3f-6d29ea630161', 'e836ba2a-4282-4e28-aa19-84708014c0e8', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('e120f2e4-a1d1-4511-8f82-cc12620f27aa', 'd1eb80f7-de39-43fc-ad28-42287769a913', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('77b531d5-4023-47db-9d0c-2efbdc60d425', 'd1eb80f7-de39-43fc-ad28-42287769a913', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('c4553ddf-57ea-4d99-9091-ddf2c671ff85', '57fb6ae9-116f-4f11-b09a-43d01b7db3eb', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('ed14828e-258e-4f37-8ff9-416f9361d001', '57fb6ae9-116f-4f11-b09a-43d01b7db3eb', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('f821ee34-f9cd-4acf-9b88-3b1973eb1d9e', '8e34ab35-c94b-463a-8683-71888dbd296f', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('8ac93566-e6d7-49f9-8891-e89b7a7b6990', '8e34ab35-c94b-463a-8683-71888dbd296f', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('3b5d2872-6a2c-4108-bac9-abfa2161404d', 'c0ffa4d5-f2dc-4ba2-a8fc-0be7e7179ead', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('15670730-25f4-4c8f-81da-e6a08d6a72b1', 'c0ffa4d5-f2dc-4ba2-a8fc-0be7e7179ead', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('66041663-4bf9-44f4-8078-a58a578ee543', 'efd23e9e-e013-49d6-b03d-133da26050f6', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('a2cf9aea-896a-4eae-aa3c-96d4e879c513', 'efd23e9e-e013-49d6-b03d-133da26050f6', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('8dd2f6fe-dda6-4d3e-9565-c77176500ed9', '7ab25a5a-c099-4775-b985-16a9bd82556f', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('dd6800b3-157d-43b2-a538-a7529c2baaa4', '7ab25a5a-c099-4775-b985-16a9bd82556f', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('21d94b74-855f-492d-a575-f2016c3b77b4', 'b4be5273-5626-413b-8485-5f90d9dbbedc', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('1c32d569-af20-4b64-99d5-d61fc87454ff', 'b4be5273-5626-413b-8485-5f90d9dbbedc', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('5ec83810-8929-4fc8-9cca-55d392ae6f80', 'ecbe4fb0-e2cc-4d6b-af8a-d4e4ef9ae15a', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('898874ec-798a-4426-b402-fc0cf4f5ff0f', 'ecbe4fb0-e2cc-4d6b-af8a-d4e4ef9ae15a', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('f6b13267-0134-4aed-a544-bbbd252ba5a4', '2560cc45-c53a-43ff-9317-a89fa97540ad', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('4202cf36-8a65-4402-acf7-fe7ddfd48161', '2560cc45-c53a-43ff-9317-a89fa97540ad', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('4a7035d9-ed6d-4cff-b573-aae12af15a20', '4f166b1b-e4f7-4c26-a6d8-cb8fc857e972', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('54e2217c-d02b-48c3-81f7-b70e7a814d39', '4f166b1b-e4f7-4c26-a6d8-cb8fc857e972', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('1d7a0c01-f7e6-4694-ab7e-ec30dc920f23', 'f2a42ffb-9313-4e53-a16a-30dd8bb75dc2', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('fd10b0ef-8df5-406f-9646-4d05bb219e44', 'f2a42ffb-9313-4e53-a16a-30dd8bb75dc2', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('da5a6736-d3f4-4b53-8cea-45117be93b55', '76538f0c-ef09-41e6-9732-3a112b7b9466', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('e1373ba4-613f-47e8-8fa2-90b9e7e70e50', '76538f0c-ef09-41e6-9732-3a112b7b9466', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('f5479121-ebd6-40a1-817c-41507a5b4e66', '0f4a2175-5ca9-4cf6-ad5c-3b6aa85f1d46', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('34c1d94b-86a0-4c9c-be0c-53230b102e64', '0f4a2175-5ca9-4cf6-ad5c-3b6aa85f1d46', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('e8038689-5972-4e72-bd4d-d661afbc0fda', '56e448e4-0b64-400d-9e84-a4be04ea1140', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('c169f30d-3678-40e4-aab1-c1f584ad2c68', '56e448e4-0b64-400d-9e84-a4be04ea1140', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('594feea1-df6d-4968-914f-33516eb44b34', '0d368876-98ee-4695-8e0e-1c909a92eb40', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('7ea6da13-17fb-41c8-9e1c-119ae7cabd05', '0d368876-98ee-4695-8e0e-1c909a92eb40', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('5793b8b4-8556-45ba-8499-28f6656ce225', 'b163daf3-3c70-4ca5-9f65-e7e0f968a85f', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('de4d2b34-add0-4171-8b4b-da6f71f4d91a', 'b163daf3-3c70-4ca5-9f65-e7e0f968a85f', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('a491af4f-c742-4ce9-98ae-e92475d76e1e', '8b4a6a0a-e0ec-436e-97e4-3514a19978b0', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('e7cde370-0b6b-4403-826e-195dfde00201', '8b4a6a0a-e0ec-436e-97e4-3514a19978b0', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('b597264a-275c-4eb5-b9a1-c389d937ecbc', 'c77ac5d8-530d-4dde-a351-7c4b7ac653f0', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('d53c2ceb-642b-4f87-9fad-4a7b2feca54e', 'c77ac5d8-530d-4dde-a351-7c4b7ac653f0', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('3cde3cc3-7cd8-44ca-ac36-1ab83690cf89', 'f24b536b-f902-4f3d-abd9-950288348ab8', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('d2ee49c9-b6d9-4d1c-9e88-531493baab70', 'f24b536b-f902-4f3d-abd9-950288348ab8', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('0cc347c1-5837-4ae7-8013-6b021fbb0c83', '00c28643-671b-4245-a8cd-8ad0edb92785', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('6ac54e14-5b3d-4503-8c5c-a1ca99d5d352', '00c28643-671b-4245-a8cd-8ad0edb92785', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('07867ce9-a4f3-465f-9f22-46db35be689c', 'e2e1afe2-1b08-49ed-9158-8de2151fe4ec', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('89108f9e-05f3-437f-ac85-5d38bae7dfde', 'e2e1afe2-1b08-49ed-9158-8de2151fe4ec', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('213ea8dd-8c37-409f-b7c0-b150cded66c1', 'c722b0f9-4041-4fa0-bc54-51f83f878f9b', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('a11e1d1f-9da6-4f4c-83ac-0de13a5787f0', 'c722b0f9-4041-4fa0-bc54-51f83f878f9b', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('299d00d8-2e7b-4e24-bbbe-32b5088a1bfa', '1acb4612-742b-4fc6-8f10-63d03d7b3f9c', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('3b34c0df-495f-42a5-958b-26fdb8d0f853', '1acb4612-742b-4fc6-8f10-63d03d7b3f9c', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('ac08964d-5712-4236-b92f-5bbfc1c576a6', 'f7cbc17f-9a47-4b5c-beb3-9d6d8e32ec5a', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('ab4d0953-b6de-41b7-929c-b6aa01a39468', 'f7cbc17f-9a47-4b5c-beb3-9d6d8e32ec5a', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('8445e1a8-419c-4cb6-820b-8b45e728f99a', '21a04880-ef0f-4e09-8d7e-34dcc558e203', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('c9cd5b9d-2063-4f27-b6fe-35829487f30d', '21a04880-ef0f-4e09-8d7e-34dcc558e203', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('c58fbbfa-8b42-43e8-bd6e-38bdecc29ae7', '616ee323-422e-49ae-b8a3-6b1d3480f315', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('7f5b1c81-65bf-4a70-abca-e7beb8a314e9', '616ee323-422e-49ae-b8a3-6b1d3480f315', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('0f0e4ce7-7c4a-4cc9-9f0d-0118e1eaa092', '64d3f85d-ea20-498e-bf2b-a7d9b2287789', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('1e2adeb9-7758-4fd2-a460-d62962b19ada', '64d3f85d-ea20-498e-bf2b-a7d9b2287789', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('c628d5fd-a668-4bbc-83a7-d3397911c15e', '4d7b7eba-a0fb-46d2-b48e-196e312c024b', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('10a46043-a8da-4f61-8166-46a04e7f7368', '4d7b7eba-a0fb-46d2-b48e-196e312c024b', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('9fc3120e-663c-4b97-b94a-fe0802a7a70b', '616ee323-422e-49ae-b8a3-6b1d3480f315', '85d80fef-9a4b-4878-b647-63301e934b51', '17:00:00', '20:00:00', '2025-06-05 06:33:05.925127+00', '2025-06-05 06:33:05.925127+00'),
	('1782e0fe-0ecd-4340-a760-45bebcc82b14', '4d7b7eba-a0fb-46d2-b48e-196e312c024b', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', '08:00:00', '20:00:00', '2025-06-05 06:34:29.775432+00', '2025-06-05 06:34:29.775432+00'),
	('ac6a5480-f9c0-4692-8789-2150bae3f127', '24bd2caa-59db-4352-8435-70b8d4f8af7b', 'c965e4e3-e132-43f0-94ce-1b41d33a9f05', '11:00:00', '18:00:00', '2025-06-05 06:36:05.2062+00', '2025-06-05 06:36:05.2062+00'),
	('83d9fac5-627b-4de7-8749-c14597f212f8', '80902bf8-c1c0-462f-a548-698571aab7d0', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('e5c485f5-2384-41c4-a2fe-0ecc15315e62', '80902bf8-c1c0-462f-a548-698571aab7d0', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('3d7ce31b-b63b-4abd-a134-5a58d0ad04f2', '0169c25d-fb19-4aa8-9e2f-e8996a124831', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('3cdd3601-fd33-4e1b-bb7a-e59c932b0edd', '0169c25d-fb19-4aa8-9e2f-e8996a124831', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('e67e2de5-69bf-442b-9d8c-bb3ebdf15d45', '497ea3f1-a167-404f-b012-820dadd5b30b', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('ca4d7a07-5340-4f75-9435-f38c82bfc1dd', '497ea3f1-a167-404f-b012-820dadd5b30b', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('d3d09992-21a7-4d21-8417-4159d397679e', 'ed9b55a5-e780-419a-aa12-d9aa0a5cbb3f', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('c5d8a5df-c4f0-4368-88c1-7147e1a2e88b', 'ed9b55a5-e780-419a-aa12-d9aa0a5cbb3f', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('3aaa081b-11eb-4d81-836a-8e1acc90b324', '6d9e0cbf-f841-4b1e-a678-4ea4019e1f0a', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('d3f5a75b-4abe-4ff0-9de9-16ed23c3f1e4', '6d9e0cbf-f841-4b1e-a678-4ea4019e1f0a', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('f553ebd3-987f-4923-b91e-c916361c0dda', 'd0a19ae0-831c-40a5-b6d2-4b7d003f2398', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('028f9f38-90fd-41bc-81e0-6e06b70e1391', 'd0a19ae0-831c-40a5-b6d2-4b7d003f2398', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('87fb0c80-ecb7-4cb0-867e-a4b838b8cdb9', '76c3e096-2f13-4662-ad43-dca9d74628c5', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('1806bdce-9bd1-45bb-8076-bdab2db19bab', '76c3e096-2f13-4662-ad43-dca9d74628c5', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('fe722960-e5ff-4538-8fe0-b46c6d0b7738', 'ec700602-befa-46f9-95a0-245b38583dd2', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('ca35ea87-197d-41b0-bfa6-014a6683e517', 'ec700602-befa-46f9-95a0-245b38583dd2', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('288b4eab-03ad-4ceb-91d2-ae8a05d8e1f6', '6d9e0cbf-f841-4b1e-a678-4ea4019e1f0a', 'af42f57f-1437-4320-b1a2-2b0051948de3', '08:00:00', '17:00:00', '2025-06-05 09:27:32.417208+00', '2025-06-05 09:27:32.417208+00'),
	('77aaf218-36eb-46eb-94e7-07a4f3ce68ca', '1eefdfcf-adf6-4c4d-af81-fb6e45ff2086', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('06a0bbfa-f744-476f-b6b4-bdac69bc47e7', '1eefdfcf-adf6-4c4d-af81-fb6e45ff2086', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('b1ff2b67-a402-40f6-b4ef-672ced6765d6', 'a625074f-bd36-4775-92be-434a0b2a87cb', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('8aa25785-4efd-4908-bcb7-11629622b347', 'a625074f-bd36-4775-92be-434a0b2a87cb', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('56b8a8ef-bfc5-4932-b48d-646dd575c103', '3b74144d-12ec-4ea5-9582-70696ac4781a', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('98f1b509-186e-47bd-8bd2-c16da7df89e7', '3b74144d-12ec-4ea5-9582-70696ac4781a', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('47453a68-b339-47f4-ba49-4f93ab942af7', '5bdfa3bb-3797-4c7c-880e-8e506d9fb98c', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('248e0355-6156-4ed8-bc35-71ce73e33644', '5bdfa3bb-3797-4c7c-880e-8e506d9fb98c', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('88b1d117-f3c8-4aca-8100-f0454dffe60d', 'b1153bca-d2e2-4329-88f9-e7c53453c4f2', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('37836a92-995b-48d2-a35b-a0dcaeb1f7d4', 'b1153bca-d2e2-4329-88f9-e7c53453c4f2', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('56ece132-d27e-4921-be62-fac19176839f', '89711d5c-c7cb-4cba-946e-7bd6a15916b4', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('f67f69f4-93c9-484f-94a6-ce8d6c0d1a6f', '89711d5c-c7cb-4cba-946e-7bd6a15916b4', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('10a62e1c-998d-4c15-9d56-6987e402aff6', '44b11262-a507-4836-9a30-275758e30444', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('13f6d301-7eba-43b8-8b0d-81d8ce7c1638', '44b11262-a507-4836-9a30-275758e30444', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('e385a7c0-f9ed-4c3b-ad74-37064e7afe0d', '1188f2f9-a4d1-421c-be31-2e7a734e22b1', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('9e62b493-67e3-43c5-8495-4b7de2392fc6', '1188f2f9-a4d1-421c-be31-2e7a734e22b1', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('5c4b9bce-8441-416d-bef0-6cff1ded6fd5', '2be16bc3-5bae-4b89-a423-49a90fe564fc', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('99850970-215f-4a3a-a833-ba08a8482f13', '2be16bc3-5bae-4b89-a423-49a90fe564fc', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('486acf54-2b50-4a06-aa39-9f7b5bfb1258', 'cd84cb0f-1dd0-4231-96fc-3013fa9f4644', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('5bbe73de-5206-4050-9a70-8fc9f4789b7d', 'cd84cb0f-1dd0-4231-96fc-3013fa9f4644', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('5673ddd6-acb4-4208-8eee-d897ee3fdb10', '76746c80-b29b-46da-9949-e1076256bff6', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('7009a511-9f30-4350-8b8d-673c42ef0c89', '76746c80-b29b-46da-9949-e1076256bff6', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('41e395f2-f280-44b9-8bcd-8063b51a928f', '51fa7d37-5dfd-4bc9-a602-0d33d0b19704', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('01fdd294-aa2a-4d81-82f7-b1f786dda430', '51fa7d37-5dfd-4bc9-a602-0d33d0b19704', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00');


--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00'),
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00');


--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_porter_pool" ("id", "shift_id", "porter_id", "created_at", "updated_at") VALUES
	('830b1855-afe4-463d-b6da-a565d09bbd08', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'ccac560c-a3ad-4517-895d-86870e9ad00a', '2025-06-03 18:16:54.220494+00', '2025-06-03 18:16:54.220494+00'),
	('b335c5e6-b72e-43dd-8df9-eda0b32134cc', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-03 18:16:54.265326+00', '2025-06-03 18:16:54.265326+00'),
	('b8a7b100-34ba-424d-b95a-77423368bcd9', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'd34fa6f7-8d2d-4e20-abda-a77c11554254', '2025-06-03 18:16:54.319909+00', '2025-06-03 18:16:54.319909+00'),
	('2d45959e-fe5f-4f43-af43-6cc5ad05d591', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'b4bcc3bc-729a-49fe-bf6e-1c30fcac37b3', '2025-06-03 18:16:54.367231+00', '2025-06-03 18:16:54.367231+00'),
	('809e6305-5d5a-4092-b894-aaff65e33715', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'b30280c2-aecc-4953-a1df-5f703bce4772', '2025-06-03 18:16:54.416226+00', '2025-06-03 18:16:54.416226+00'),
	('d7b33fce-61ed-44c5-918e-668053377ca3', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-06-03 18:16:54.465155+00', '2025-06-03 18:16:54.465155+00'),
	('404fb567-9b9a-4f9b-8b3d-8163034acedf', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '2025-06-03 18:16:54.516023+00', '2025-06-03 18:16:54.516023+00'),
	('865e63c8-6ce8-45b7-a6f8-034614aa8acc', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'd34fa6f7-8d2d-4e20-abda-a77c11554254', '2025-06-04 10:53:34.91423+00', '2025-06-04 10:53:34.91423+00'),
	('fe0f44cf-342b-4431-9145-8a446cb9e432', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'aeac1145-0b87-403a-81db-72b516a9fe15', '2025-06-04 10:53:34.987329+00', '2025-06-04 10:53:34.987329+00'),
	('8ced42a1-ff4b-4e37-a741-2aabaa6fd95e', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '2025-06-05 06:28:00.879838+00', '2025-06-05 06:28:00.879838+00'),
	('81dcb50a-93d6-4973-a2a2-8e8642a10611', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '2025-06-05 06:28:00.958486+00', '2025-06-05 06:28:00.958486+00'),
	('6471693f-70b9-403a-863d-07b1475fa30e', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '2025-06-05 06:28:01.069479+00', '2025-06-05 06:28:01.069479+00'),
	('10bb762e-4f88-4586-9e2a-9bc56b133573', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '2025-06-05 06:28:01.133516+00', '2025-06-05 06:28:01.133516+00'),
	('9940603f-579d-490b-a516-18768fe6ab33', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '2025-06-05 06:28:01.188444+00', '2025-06-05 06:28:01.188444+00'),
	('e3bdb9d6-8afa-4e5b-95ad-468a173ba6b2', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '2025-06-05 06:28:01.254025+00', '2025-06-05 06:28:01.254025+00'),
	('c26b991f-2548-4ebb-9028-c04e49dbff37', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', '2025-06-05 06:28:01.313006+00', '2025-06-05 06:28:01.313006+00'),
	('76e24ce6-d2b9-4633-bd94-ce8eae735a98', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '83fdb588-e638-47ae-b726-51f83a4378c7', '2025-06-05 06:28:01.364486+00', '2025-06-05 06:28:01.364486+00'),
	('0a1574c1-3e9f-4589-9f79-70ad54c147d7', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '85d80fef-9a4b-4878-b647-63301e934b51', '2025-06-05 06:29:03.747422+00', '2025-06-05 06:29:03.747422+00'),
	('fa91dd5f-3564-4750-a76d-75f28ef44bbc', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'c965e4e3-e132-43f0-94ce-1b41d33a9f05', '2025-06-05 06:29:44.263667+00', '2025-06-05 06:29:44.263667+00'),
	('49eb7baf-9641-46b7-ba61-5eb6283a0c9e', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '7baf82c3-c592-43fa-aac0-b53fbd8e9a1d', '2025-06-05 06:29:44.339463+00', '2025-06-05 06:29:44.339463+00'),
	('ff16f9cc-819c-4d40-b8de-65fdf28802cc', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('f6c96ccf-678b-4429-b131-ecfc216a614a', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('f3807302-efb4-47b0-834e-b50563224db1', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('235d8799-fa26-4114-9412-8519c091277b', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('a52d90e9-b112-4772-a5ad-853f75ee6b61', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('f1730068-7ecc-4717-b3cc-75d5951dadff', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('af558122-d736-433a-8b10-1755cc380a5e', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('26d340fb-249c-4a13-8e69-810e606f47b0', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '83fdb588-e638-47ae-b726-51f83a4378c7', '2025-06-05 08:34:30.084827+00', '2025-06-05 08:34:30.084827+00'),
	('00a004cd-1a8b-4f38-b5c4-516fad3a5235', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-05 09:27:23.244694+00', '2025-06-05 09:27:23.244694+00'),
	('f56f4f72-c21d-42e4-9f9e-e44d2725fe62', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', 'd34fa6f7-8d2d-4e20-abda-a77c11554254', '2025-06-05 09:27:23.290671+00', '2025-06-05 09:27:23.290671+00'),
	('df776f06-9672-4374-8af6-1be4226388ed', '7700370b-ea09-4d37-ae48-5226c13be7cc', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-05 09:27:58.977003+00', '2025-06-05 09:27:58.977003+00'),
	('541fbe74-ccb7-48c3-99a5-57fa8534aebf', '7700370b-ea09-4d37-ae48-5226c13be7cc', 'd34fa6f7-8d2d-4e20-abda-a77c11554254', '2025-06-05 09:27:58.977003+00', '2025-06-05 09:27:58.977003+00'),
	('494f7096-1b7b-459d-ac59-fc1924a39930', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-05 09:28:15.163836+00', '2025-06-05 09:28:15.163836+00'),
	('63f049c0-7537-4753-b283-a39b9a09c11e', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', 'd34fa6f7-8d2d-4e20-abda-a77c11554254', '2025-06-05 09:28:15.163836+00', '2025-06-05 09:28:15.163836+00'),
	('62572ffa-ebdc-4b87-be2a-ab2da6621b54', '5cd73045-8fb5-42dc-bacd-20408a628e94', '296edb55-91eb-4d73-aa43-54840cbbf20c', '2025-06-11 11:25:39.65278+00', '2025-06-11 11:25:39.65278+00'),
	('ec211fe6-c16d-4550-812a-ca67edc644f6', '5cd73045-8fb5-42dc-bacd-20408a628e94', 'ccac560c-a3ad-4517-895d-86870e9ad00a', '2025-06-11 11:25:39.753316+00', '2025-06-11 11:25:39.753316+00'),
	('e39d3b65-ecb0-4e42-b46f-36162be10db4', '5cd73045-8fb5-42dc-bacd-20408a628e94', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', '2025-06-11 11:25:39.813793+00', '2025-06-11 11:25:39.813793+00');


--
-- Data for Name: shift_support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_assignments" ("id", "shift_id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('3d7a06e4-c869-4b88-839b-4f9c6915d6cf', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('63472e68-c6b8-482b-aa96-cbd79f3f1262', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('93583805-4b67-40ad-9946-f21b6951f992', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b642c234-ebf8-4126-9933-82d62cdf3361', '96d2f593-03bc-43f0-8f0b-22fc795e4882', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b645b96c-70fa-408c-937c-e94954d8c19f', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('758eb253-2464-40cc-b9ac-2f8ea6d9f2f5', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('473f6135-76d3-40cb-ad3a-120c5a7e03e3', '96d2f593-03bc-43f0-8f0b-22fc795e4882', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('edb6a6fb-6fe5-498d-abae-3c83cbd27cb0', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1a9c5002-05d8-4919-b40c-30b908db0f6a', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ceabde63-c2b9-433d-b54e-d09ed466a20f', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ddb64556-b0d5-4d6d-b364-f4031188c05f', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('79722923-88c6-44f4-a6ab-cbde3f2e0069', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7defbf7a-cea5-42a8-9903-d5e21486aa24', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d674fc20-3b14-4638-ae3b-a87b416d323b', '7aa24983-5a3e-4d74-a2d5-c5e83a2c90c5', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('790ca418-b9ff-404c-9a35-e9887204e45a', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c21278fc-a3f1-4c57-9021-ad1c706c655d', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('eb30928c-4a16-42f6-b6cf-ba5a10cf2630', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5729ec6a-b2b0-4fb1-982f-e68c0d30ef6a', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('bdf3e259-0f14-4d2b-a66e-e8206e109df5', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c070c2fd-887f-4122-9ca0-0f0927c56710', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9939793b-47fb-494a-8269-13c7867e8f73', 'd10c030e-fe11-4370-9062-4a202cfc9e3b', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e67dda5f-d1de-4324-8f29-575f2f17d8d7', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d27fdaff-12dc-49fd-8a73-5704252d84d7', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d9da83d1-9696-4f55-a08f-a4704095f475', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('86b5fc5e-9678-4eae-a279-fe696bb95d8e', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('bb04e7c1-1ff4-48aa-a201-935cb2f34171', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0183c4a3-45e0-4d6a-8d6e-9176d46c0a19', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('213eb236-b05e-4ede-91ab-019790e66bfe', 'fc70a0dc-6a17-4851-96f3-2f3f4382285c', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7a43e4ca-5a50-45dc-a761-c01e8573d89b', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fef0b67a-3b6b-4291-918f-cbe417c3e06d', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b22ad107-f96a-4628-a5df-fbb840ec9ca7', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('040fe7af-851a-4d4b-ac6d-4d0c95e69d57', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a1ef2aa1-1b01-4d73-b9e8-dbcd0dc3039a', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cc55af49-f446-4f08-8c91-169f6b03ab8c', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7f86dcd4-9145-494b-aebe-69996eba437e', 'ca8fe410-afa5-4a0a-83c0-bb2195fec54a', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('37aed9c3-d66a-4f5d-8f81-40166d5f08f2', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('dff35219-d710-407e-9e02-110121c66873', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d9fa66bd-64e8-4d3d-9203-24a367993f29', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9e52777b-4622-4c27-8c89-a819c39fd27d', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a0895d60-d2fd-4433-a10d-1a05f1bcfdd2', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a75c6b59-99e4-41f5-8564-38e5bcb5d9f8', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fd55d23b-9233-4b2f-b138-f198f06e7205', '7459a9f5-e7f9-4e59-8ffc-6fd39657f442', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f1de9229-bc8e-4cc0-9af5-0e796faefcf1', '5b434b59-050e-429b-a95f-c71b9c67772a', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a96614a4-02ed-49bc-8034-7e0208ff79b0', '5b434b59-050e-429b-a95f-c71b9c67772a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('82876014-4bca-434c-9c2c-6379c66ff26a', '5b434b59-050e-429b-a95f-c71b9c67772a', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fc3f2b70-aa0e-44f8-bed2-be7eb29cf4e6', '5b434b59-050e-429b-a95f-c71b9c67772a', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('3b5cad08-7c9e-46bc-9707-42f06e4ecc08', '5b434b59-050e-429b-a95f-c71b9c67772a', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('12d133c2-1428-48cb-8b6e-6f9b83238e83', '5b434b59-050e-429b-a95f-c71b9c67772a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5082dd7d-05c5-4089-989c-bfb39eea0fd6', '5b434b59-050e-429b-a95f-c71b9c67772a', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0f09322f-1ee7-4bf7-bf89-407b5616653b', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c9582bdc-289f-4d98-9e81-4178850a54d1', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1be99965-3a0c-4c19-9fab-54d26d54a0e6', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6e727a83-b684-4f68-95ac-c64424ac99c1', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('a594fd3c-e44a-4c79-95cb-df8de42a160d', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3c80290e-d87c-4a87-9ae7-97d16f8dbbbe', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6ec27a0a-2e19-4ca7-a856-c4a6673e69c8', '8b01a9fd-69a5-467a-be3d-97cd0541bc8d', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4cbd5efd-e465-4fb7-badd-91f494d2bff3', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('889d8493-ca1e-4f21-9bf8-94eadc977c7c', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('eead43cf-667c-4ea6-b6c4-9b79cde457e8', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5fca6941-f1d4-420a-8207-7ca2bb4f71c4', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('2d5e82a2-2031-499b-8ede-7031746dd32a', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c636b4cf-5534-4541-90ff-1d7e7b3f391d', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4c789ec3-59fd-458b-b6ac-0c91428755f0', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('3d2d6a89-ca32-4d25-9198-f1be301cb332', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('329b10e8-5a55-4453-8537-31e701b15050', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('462a4187-c4b3-4be5-88e4-c64c72add8c8', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2ca520a7-289a-4c0a-97f1-8420cb5adae1', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('6d044e13-84f2-4113-8f26-218c58a55d93', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ba768b43-fdba-4152-b019-3d95c90b523f', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('cecdcc2b-b9cd-480e-ba99-48424f9c3f7b', '6f63d3c4-c4ef-4363-948b-eb0befbb9c5c', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('f518aeb0-94a8-473c-924f-8244b2aaab9c', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('c0f745fb-9848-47de-8645-100e9109fce7', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4fedb224-2f6b-4621-bc6d-bdbb696a28db', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('84f09fdd-0cec-4942-94f6-1de6d6da5abf', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('06a02a5c-1a54-4488-8dfe-ea93bd25b267', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5515efd3-c490-4de5-8fae-e77709423f91', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('e5475670-11b7-4d44-a03d-7ba876847dc2', '24c2b9c8-bcd0-46d5-9571-c86790690ef5', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('417778b5-997f-4e56-b7d3-6f6497b36069', '7700370b-ea09-4d37-ae48-5226c13be7cc', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('a7070e6b-af25-41a1-8a16-476d1351a4f7', '7700370b-ea09-4d37-ae48-5226c13be7cc', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4c0be928-cca2-4b3e-9408-9cae09f42bf7', '7700370b-ea09-4d37-ae48-5226c13be7cc', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('268e0dea-1e9f-4c98-a384-b7f4c57900a5', '7700370b-ea09-4d37-ae48-5226c13be7cc', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('40fc1166-dbcd-4fbe-a823-9ed53b268afb', '7700370b-ea09-4d37-ae48-5226c13be7cc', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('08d7c6a0-6c1f-458c-b6b6-827f69d103e2', '7700370b-ea09-4d37-ae48-5226c13be7cc', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('c47c4503-2d7a-4941-86f1-8d4e0a9937b4', '7700370b-ea09-4d37-ae48-5226c13be7cc', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('921731d5-9da3-4089-8419-6d7f0d6ada40', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('ebd7428e-1d33-471c-bdec-fc24fa09222d', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('21618887-8af9-4005-84ce-40eb6a41a094', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('eb4e205d-0e9e-48c5-91ca-a110c501e7a4', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('a05979b0-f7c4-4caa-a58a-f372a1aaca5b', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('14b6918f-2524-4981-ad35-77b592d5956d', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('269261bc-da13-4c2d-b830-3091e1b1e9e4', '49577c3f-f64f-4d62-ac20-e7ead42bed6e', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('8b5eaa1a-f362-4def-9895-6485dc65ae4e', '5cd73045-8fb5-42dc-bacd-20408a628e94', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('467e4d28-34aa-4ed3-b86a-687280d84e15', '5cd73045-8fb5-42dc-bacd-20408a628e94', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0be5deb2-5469-4e7b-a458-2f1c57cacd6f', '5cd73045-8fb5-42dc-bacd-20408a628e94', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('21e0ad1a-d28e-4bd3-88bf-4a62af3ac5ad', '5cd73045-8fb5-42dc-bacd-20408a628e94', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('d3a29ef5-3c0c-4f27-81ac-dd192f1799e8', '5cd73045-8fb5-42dc-bacd-20408a628e94', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e36b14a6-e8d7-447f-8fab-8b454575f369', '5cd73045-8fb5-42dc-bacd-20408a628e94', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('f54b8b3d-cb12-4a63-909d-a55259c043c2', '5cd73045-8fb5-42dc-bacd-20408a628e94', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00', 2, 2, 2, 2, 2, 2, 2, 2);


--
-- Data for Name: shift_support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_porter_assignments" ("id", "shift_support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('6b186cd8-4206-4ae2-952d-898159199de4', 'b642c234-ebf8-4126-9933-82d62cdf3361', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('142df6ba-1c31-40e1-b584-35d1958687d2', 'b642c234-ebf8-4126-9933-82d62cdf3361', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('af0a1ddf-9a35-414f-9082-760a1b5afa9f', 'b642c234-ebf8-4126-9933-82d62cdf3361', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('1b392143-a8a2-4f6c-8aef-20e4963f7e7e', 'b642c234-ebf8-4126-9933-82d62cdf3361', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('a3a22def-f07c-4d60-a98c-0a7544e345dc', 'b645b96c-70fa-408c-937c-e94954d8c19f', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('22d68f96-9340-4076-98bc-ef8128a62875', 'b645b96c-70fa-408c-937c-e94954d8c19f', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('da93695d-6ed0-405f-9d82-d7935836fcd9', '473f6135-76d3-40cb-ad3a-120c5a7e03e3', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 18:02:04.950622+00', '2025-06-03 18:02:04.950622+00'),
	('7d5e25d8-e328-42da-874d-f05ca2c3af49', '3d7a06e4-c869-4b88-839b-4f9c6915d6cf', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '09:00:00', '17:00:00', '2025-06-03 18:17:41.852909+00', '2025-06-03 18:17:41.852909+00'),
	('75be1a87-dd5c-49c5-ad30-105a39700e72', 'ddb64556-b0d5-4d6d-b364-f4031188c05f', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('037fec24-2493-422f-9ae3-860394209fe6', 'ddb64556-b0d5-4d6d-b364-f4031188c05f', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('c990c022-9d95-4bae-b8df-7a60149b7337', 'ddb64556-b0d5-4d6d-b364-f4031188c05f', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('6d89ea46-133d-4787-9f46-2c810860957f', 'ddb64556-b0d5-4d6d-b364-f4031188c05f', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('f1c38a6e-8a6c-4856-83fc-d684b961f04d', '79722923-88c6-44f4-a6ab-cbde3f2e0069', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('67bf90fa-a309-431e-a943-a36bdb95d955', '79722923-88c6-44f4-a6ab-cbde3f2e0069', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('3502fe6f-a82f-440c-8451-87feb7cd0f0b', 'd674fc20-3b14-4638-ae3b-a87b416d323b', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-04 09:34:04.700211+00', '2025-06-04 09:34:04.700211+00'),
	('6b7699d8-738c-454c-9178-662fadd5b262', '5729ec6a-b2b0-4fb1-982f-e68c0d30ef6a', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('93659376-b2b8-45b7-8cc9-255f3abe9fd0', '5729ec6a-b2b0-4fb1-982f-e68c0d30ef6a', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('9897ff9c-6f25-4f53-9f22-d5e2ac38aca7', '5729ec6a-b2b0-4fb1-982f-e68c0d30ef6a', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('89bbff61-b264-4e85-9c9e-c095dda643a3', '5729ec6a-b2b0-4fb1-982f-e68c0d30ef6a', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('9da8119b-6f38-44cf-863b-4ac875e2576d', 'bdf3e259-0f14-4d2b-a66e-e8206e109df5', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('db857cb3-9a7c-40eb-9566-62973d7ac044', 'bdf3e259-0f14-4d2b-a66e-e8206e109df5', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('8b962de3-b53f-454c-a396-95c650818223', '9939793b-47fb-494a-8269-13c7867e8f73', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-04 10:52:39.201116+00', '2025-06-04 10:52:39.201116+00'),
	('d9b2bc59-4681-4484-a077-ba7b8a21de0b', '86b5fc5e-9678-4eae-a279-fe696bb95d8e', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('cc8ec5ba-9306-471f-a3fe-497d6a448ac7', '86b5fc5e-9678-4eae-a279-fe696bb95d8e', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('3eae3bb4-9d6d-427b-9e77-d26e2d4f6b8a', '86b5fc5e-9678-4eae-a279-fe696bb95d8e', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('8e97f70c-0cf6-4da8-b301-0a989a867406', '86b5fc5e-9678-4eae-a279-fe696bb95d8e', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('a9af7e7b-967d-4776-bb88-f56246ef86df', 'bb04e7c1-1ff4-48aa-a201-935cb2f34171', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('a8874bfa-c3d1-4719-be17-b592cfe752f5', 'bb04e7c1-1ff4-48aa-a201-935cb2f34171', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('6f60252c-f7e8-465b-bf2d-e5e5b00353e4', '213eb236-b05e-4ede-91ab-019790e66bfe', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-04 10:53:17.880612+00', '2025-06-04 10:53:17.880612+00'),
	('480b38ee-3623-4f7b-908d-e8f4524c52d6', '040fe7af-851a-4d4b-ac6d-4d0c95e69d57', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('e7320c64-3c46-47cd-b166-e12dc8abcdc8', '040fe7af-851a-4d4b-ac6d-4d0c95e69d57', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('7ff0b1a7-a3c4-4974-9f3d-0690b7c47c1f', '040fe7af-851a-4d4b-ac6d-4d0c95e69d57', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('6b667a3d-dcb4-4deb-a100-8535aba631bd', '040fe7af-851a-4d4b-ac6d-4d0c95e69d57', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('47cf6416-c26c-4f03-b97e-2b4198ddf504', 'a1ef2aa1-1b01-4d73-b9e8-dbcd0dc3039a', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('27db8a4c-bc5a-4fb9-860f-1aeede3bcdca', 'a1ef2aa1-1b01-4d73-b9e8-dbcd0dc3039a', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('1b77b06f-05bc-499b-ba3f-e38f13f09514', '7f86dcd4-9145-494b-aebe-69996eba437e', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-04 11:16:25.652245+00', '2025-06-04 11:16:25.652245+00'),
	('225f3df8-8d4b-4634-9605-ff624cca7007', '9e52777b-4622-4c27-8c89-a819c39fd27d', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('0c00700c-1156-47a7-ae80-314db22a1a7e', '9e52777b-4622-4c27-8c89-a819c39fd27d', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('5d761f2c-07d3-4fcf-b1d9-159cd17627c7', '9e52777b-4622-4c27-8c89-a819c39fd27d', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('aa1d0d72-6cf3-46d8-b4dd-4288a698b661', '9e52777b-4622-4c27-8c89-a819c39fd27d', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('b1b43533-ccfe-481d-a9fa-e5a62ec34b0b', 'a0895d60-d2fd-4433-a10d-1a05f1bcfdd2', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('d315e602-7912-4f98-ab9c-1d1e0052209f', 'a0895d60-d2fd-4433-a10d-1a05f1bcfdd2', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('c30a62fd-1f54-48df-8c9d-65cc6467b4d6', 'fd55d23b-9233-4b2f-b138-f198f06e7205', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-04 11:29:48.838051+00', '2025-06-04 11:29:48.838051+00'),
	('8ba5a754-c91f-4805-a423-20b35c0020c2', 'fc3f2b70-aa0e-44f8-bed2-be7eb29cf4e6', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('57693b3b-9a81-49e8-8f3e-0901d3b0d5b8', 'fc3f2b70-aa0e-44f8-bed2-be7eb29cf4e6', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('ae406170-c87e-42ca-ad1b-e8aef09f277e', 'fc3f2b70-aa0e-44f8-bed2-be7eb29cf4e6', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('591f7ef5-85dd-4360-aec0-7e71473d7dbc', 'fc3f2b70-aa0e-44f8-bed2-be7eb29cf4e6', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('196fdc9b-c2c9-4ca1-be05-b0b01390482f', '3b5cad08-7c9e-46bc-9707-42f06e4ecc08', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('924ce3ac-1630-420f-a07f-432cb744cfbc', '3b5cad08-7c9e-46bc-9707-42f06e4ecc08', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('0ab602c7-5c37-4514-9c5a-916036007a00', '5082dd7d-05c5-4089-989c-bfb39eea0fd6', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-04 11:44:21.654823+00', '2025-06-04 11:44:21.654823+00'),
	('b726ebf3-940d-45fc-b097-e03f906c15ed', '6e727a83-b684-4f68-95ac-c64424ac99c1', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('7405aaa4-96a1-45f1-907c-eba96e17670f', '6e727a83-b684-4f68-95ac-c64424ac99c1', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('19532b0c-0fcb-4d5b-966c-7685eae37a6f', '6e727a83-b684-4f68-95ac-c64424ac99c1', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('54103bbd-676b-4e82-92df-ae737f7b249c', '6e727a83-b684-4f68-95ac-c64424ac99c1', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('81468c12-24de-45e8-8c3b-55406a344562', 'a594fd3c-e44a-4c79-95cb-df8de42a160d', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('39065386-20b3-4c2c-9b86-c787b380c719', 'a594fd3c-e44a-4c79-95cb-df8de42a160d', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('6b0c33a7-e9f5-4275-aaad-ceefa4c4a4f6', '6ec27a0a-2e19-4ca7-a856-c4a6673e69c8', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-05 04:31:08.353754+00', '2025-06-05 04:31:08.353754+00'),
	('eefb9545-8275-41e8-8786-feb0b64907b9', '4cbd5efd-e465-4fb7-badd-91f494d2bff3', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('d6c7806b-15b0-40bf-81c7-6d860b62c111', '4cbd5efd-e465-4fb7-badd-91f494d2bff3', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('33407a3b-3cdb-464b-bcfc-80860a6d2d57', '4cbd5efd-e465-4fb7-badd-91f494d2bff3', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('2e269fe7-28d9-41fe-921a-1e2297b06a94', '889d8493-ca1e-4f21-9bf8-94eadc977c7c', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('793c36ca-ef12-4d6d-bc2e-cd0950c1c39d', 'eead43cf-667c-4ea6-b6c4-9b79cde457e8', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('9f957f18-5ef3-497f-8114-06dcae488fa6', 'eead43cf-667c-4ea6-b6c4-9b79cde457e8', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('0b0293bd-fb8b-4b1b-9b67-b7142b3cfb90', '5fca6941-f1d4-420a-8207-7ca2bb4f71c4', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('0801d929-16da-403a-8763-0787a408f5c9', '5fca6941-f1d4-420a-8207-7ca2bb4f71c4', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('dfc423d2-3e36-4b8d-8a02-210907c864f8', '5fca6941-f1d4-420a-8207-7ca2bb4f71c4', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('5107fb1c-81c2-4fbb-a2c9-d00cbf0cf723', '5fca6941-f1d4-420a-8207-7ca2bb4f71c4', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('87cfb68c-9dc1-4f79-a554-f7363c5abe8f', '2d5e82a2-2031-499b-8ede-7031746dd32a', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('ef35901a-0a0b-4a96-8777-fc9d7831e7df', '2d5e82a2-2031-499b-8ede-7031746dd32a', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('a570ea5d-0fc2-402d-9b1b-760a7a6575c8', '4c789ec3-59fd-458b-b6ac-0c91428755f0', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('5fdcb75a-0a29-4919-a4cf-9f60d704e4d5', '4c789ec3-59fd-458b-b6ac-0c91428755f0', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 05:49:15.231159+00', '2025-06-05 05:49:15.231159+00'),
	('1d7de5cf-e38b-4a91-9707-0923c4d5ab59', '3d2d6a89-ca32-4d25-9198-f1be301cb332', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('cf020426-75f1-4dd3-b8a5-33331736be4e', '3d2d6a89-ca32-4d25-9198-f1be301cb332', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('08243dcc-ed01-4e55-95e2-957aa55f71b4', '3d2d6a89-ca32-4d25-9198-f1be301cb332', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('7e77e7a3-ab7d-4bc0-96ba-20c198537ce2', '329b10e8-5a55-4453-8537-31e701b15050', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('27334e06-b3a3-482c-8cfe-eb9b8df02c31', '462a4187-c4b3-4be5-88e4-c64c72add8c8', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('d6645e80-77a1-4b70-9600-96fbb167267b', '462a4187-c4b3-4be5-88e4-c64c72add8c8', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('18fc3b8e-0c0d-4b9f-982e-3d9e1e16e8ba', '2ca520a7-289a-4c0a-97f1-8420cb5adae1', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('7f596564-4d1d-465e-afb7-19aed9d8b260', '2ca520a7-289a-4c0a-97f1-8420cb5adae1', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('c256e757-25ff-4574-bbb1-2a2c0e4e4529', '2ca520a7-289a-4c0a-97f1-8420cb5adae1', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('bbba35fe-d661-4cd4-86b0-514885b81451', '2ca520a7-289a-4c0a-97f1-8420cb5adae1', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('bd5a40da-91aa-40bb-b199-4d95eea8eec2', '6d044e13-84f2-4113-8f26-218c58a55d93', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('fbc28411-c49b-4b73-becc-2f5ae1bf4133', '6d044e13-84f2-4113-8f26-218c58a55d93', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('f5d9f5d9-fc30-4446-92cb-c396de3d7dab', 'ba768b43-fdba-4152-b019-3d95c90b523f', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('6abca8da-b098-4bf6-9f53-28cf44df9733', 'ba768b43-fdba-4152-b019-3d95c90b523f', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('50efa4e8-c2db-4cfa-89ce-1b5325549dd4', 'cecdcc2b-b9cd-480e-ba99-48424f9c3f7b', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('84292493-846b-4797-a898-7001bac33467', 'cecdcc2b-b9cd-480e-ba99-48424f9c3f7b', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 08:34:29.808276+00', '2025-06-05 08:34:29.808276+00'),
	('5de1b6af-bec0-464f-84e2-2b9f596c95fa', 'f518aeb0-94a8-473c-924f-8244b2aaab9c', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('690ac29f-0023-487c-9f8f-b89d89ff8722', 'f518aeb0-94a8-473c-924f-8244b2aaab9c', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('49b01f8c-8817-446c-872c-22a5b68f015e', 'f518aeb0-94a8-473c-924f-8244b2aaab9c', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('96ed0a11-3918-451e-9499-da62609f56e3', 'c0f745fb-9848-47de-8645-100e9109fce7', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('04e75674-51b2-4852-9cda-d702a8167e93', '4fedb224-2f6b-4621-bc6d-bdbb696a28db', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('39bc0e0a-c073-43ed-9537-ff9e0eb78150', '4fedb224-2f6b-4621-bc6d-bdbb696a28db', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('1d75d259-4756-4886-a5de-6ef3ecce95aa', '84f09fdd-0cec-4942-94f6-1de6d6da5abf', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('4ca3c9c4-b271-4830-b074-27feb34689f2', '84f09fdd-0cec-4942-94f6-1de6d6da5abf', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('b3e5d17d-d680-41c9-82f6-b160a35a495d', '84f09fdd-0cec-4942-94f6-1de6d6da5abf', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('c9c1baa3-7fd0-41d6-b3e9-0273bfe85d4e', '84f09fdd-0cec-4942-94f6-1de6d6da5abf', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('e56f117d-1eac-4a23-8076-c340dd0c68a9', '06a02a5c-1a54-4488-8dfe-ea93bd25b267', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('2e07c3d8-f0b1-4753-92e9-08f6656d1bf2', '06a02a5c-1a54-4488-8dfe-ea93bd25b267', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('63cdc456-cef9-4db4-af04-12dd20fc4f51', '5515efd3-c490-4de5-8fae-e77709423f91', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('7f7b00a4-f372-4dac-a1e2-b2f6c5132423', '5515efd3-c490-4de5-8fae-e77709423f91', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('3e1d2829-ec0d-4e5d-a7b2-96ac3928d2fb', 'e5475670-11b7-4d44-a03d-7ba876847dc2', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('8abc0485-993c-4b6a-8de6-d6e7479bcdee', 'e5475670-11b7-4d44-a03d-7ba876847dc2', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 09:27:17.296174+00', '2025-06-05 09:27:17.296174+00'),
	('7206cf37-ce8c-4a44-a666-d9730c399309', '417778b5-997f-4e56-b7d3-6f6497b36069', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('f361cfd1-6d3e-4773-9115-960552a4b36d', '417778b5-997f-4e56-b7d3-6f6497b36069', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('82d791bb-f67c-48d0-aefa-239c2fccba04', '417778b5-997f-4e56-b7d3-6f6497b36069', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('66672e31-e86a-4a78-90ba-c149a5dd4922', 'a7070e6b-af25-41a1-8a16-476d1351a4f7', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('8ec15cd6-980d-4cbb-9e43-2222681c23ea', '4c0be928-cca2-4b3e-9408-9cae09f42bf7', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('9ce66174-8693-4335-9129-5e1bf64b017a', '4c0be928-cca2-4b3e-9408-9cae09f42bf7', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('098d56a4-7626-48f6-a9dc-4db230213c41', '268e0dea-1e9f-4c98-a384-b7f4c57900a5', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('fd67148e-3472-4822-bc8c-f9f103d85b34', '268e0dea-1e9f-4c98-a384-b7f4c57900a5', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('c405dd2d-bd9e-489d-9c08-c30ec9f70066', '268e0dea-1e9f-4c98-a384-b7f4c57900a5', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('2cfcb5cf-46ac-49bd-a42d-8a95269e0963', '268e0dea-1e9f-4c98-a384-b7f4c57900a5', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('bdd9f487-c9e6-4b99-95ba-faf783f49e03', '40fc1166-dbcd-4fbe-a823-9ed53b268afb', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('e15f0c09-0f23-4d1b-a33f-f822330bcc56', '40fc1166-dbcd-4fbe-a823-9ed53b268afb', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('b80dd7ca-ffba-457a-b1a4-146b317e5be2', '08d7c6a0-6c1f-458c-b6b6-827f69d103e2', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('5bfbb30d-2986-4501-a83d-b3cff6ce5f57', '08d7c6a0-6c1f-458c-b6b6-827f69d103e2', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('d99171b2-f992-4742-a852-932ce7e1856a', 'c47c4503-2d7a-4941-86f1-8d4e0a9937b4', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('3c993912-fe1b-4520-b56b-ec74d67305e6', 'c47c4503-2d7a-4941-86f1-8d4e0a9937b4', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 09:27:58.834686+00', '2025-06-05 09:27:58.834686+00'),
	('18f7f402-bae1-4d7e-9c25-d0ba8d90251c', '921731d5-9da3-4089-8419-6d7f0d6ada40', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('7384539b-5e48-4c25-a9e3-de07b38deae7', '921731d5-9da3-4089-8419-6d7f0d6ada40', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('6b059a46-73c7-4c34-bef0-7e2c41da053c', '921731d5-9da3-4089-8419-6d7f0d6ada40', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('d5a4d26c-b8f2-4150-8c61-fd3817503538', 'ebd7428e-1d33-471c-bdec-fc24fa09222d', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('7bf8e4b4-2c08-4244-abc4-05f518aab320', '21618887-8af9-4005-84ce-40eb6a41a094', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('e7fb869a-0c78-44f0-a772-68fb23499cce', '21618887-8af9-4005-84ce-40eb6a41a094', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('ec65ff72-3267-4888-ae32-05b141106fe6', 'eb4e205d-0e9e-48c5-91ca-a110c501e7a4', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('7ceefd8e-8abc-44e9-b3cf-85c83213be88', 'eb4e205d-0e9e-48c5-91ca-a110c501e7a4', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('6cad7032-46df-4143-95f4-30d6a30f5f3f', 'eb4e205d-0e9e-48c5-91ca-a110c501e7a4', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('4e1d83f8-e9eb-45de-a017-31494678bba2', 'eb4e205d-0e9e-48c5-91ca-a110c501e7a4', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('5bfcaf02-5969-4c90-aba8-5de666f1980e', 'a05979b0-f7c4-4caa-a58a-f372a1aaca5b', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('7394ea8c-dfd1-46c2-86c3-4d6056c50e5c', 'a05979b0-f7c4-4caa-a58a-f372a1aaca5b', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('f5ca626c-04fa-40d3-9d21-0d83886ce74b', '14b6918f-2524-4981-ad35-77b592d5956d', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('a3979063-767e-4c52-b564-468302a24ccd', '14b6918f-2524-4981-ad35-77b592d5956d', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('cd14bb9b-8d00-446b-af4f-2ea89c79d677', '269261bc-da13-4c2d-b830-3091e1b1e9e4', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('6593113b-cfaa-4da6-afaf-5f9da0f74fcd', '269261bc-da13-4c2d-b830-3091e1b1e9e4', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 09:28:15.050963+00', '2025-06-05 09:28:15.050963+00'),
	('607093db-4159-4eb3-a33b-43ffb1d3b3a0', '8b5eaa1a-f362-4def-9895-6485dc65ae4e', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('d45f7933-63a4-4552-9f64-b5e950a61235', '8b5eaa1a-f362-4def-9895-6485dc65ae4e', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('22ff0768-ce2d-4451-9f54-8ee43985ee3c', '8b5eaa1a-f362-4def-9895-6485dc65ae4e', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('9e8b82aa-b570-4839-a6d0-79e024db9c1a', '467e4d28-34aa-4ed3-b86a-687280d84e15', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('87fbd31b-c7c2-4164-9125-cc1eb2fbfd9d', '0be5deb2-5469-4e7b-a458-2f1c57cacd6f', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('c688de6d-6a69-475a-b63d-20b36dc58dfa', '0be5deb2-5469-4e7b-a458-2f1c57cacd6f', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('0f499584-13ed-42d8-8d68-f38d539e8abf', '21e0ad1a-d28e-4bd3-88bf-4a62af3ac5ad', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('ca5d006c-d653-4516-90af-177a78f805d7', '21e0ad1a-d28e-4bd3-88bf-4a62af3ac5ad', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('45bf3583-cc94-481b-a1ec-654d76d8f633', '21e0ad1a-d28e-4bd3-88bf-4a62af3ac5ad', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('168544e0-7d81-4b48-b4cb-6d1f1d42f6f4', '21e0ad1a-d28e-4bd3-88bf-4a62af3ac5ad', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('37994bdc-6939-43f1-b4ba-fc375a8e103a', 'd3a29ef5-3c0c-4f27-81ac-dd192f1799e8', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('67bdcd1b-799b-4287-bbbb-ec974ea1b0e7', 'd3a29ef5-3c0c-4f27-81ac-dd192f1799e8', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('6de8061b-614e-4b57-8465-6743add1e344', 'e36b14a6-e8d7-447f-8fab-8b454575f369', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('3f242998-79d1-4617-9abb-2499088f4986', 'e36b14a6-e8d7-447f-8fab-8b454575f369', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('1dbd8455-253a-4cfc-a468-18b5f93e742c', 'f54b8b3d-cb12-4a63-909d-a55259c043c2', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00'),
	('9999c984-a4f4-4091-8a52-351c6cb48245', 'f54b8b3d-cb12-4a63-909d-a55259c043c2', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-11 05:53:15.39743+00', '2025-06-11 05:53:15.39743+00');


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('8a8fb7d2-32f2-4aab-b6cb-320b098da18e', '9d0f8517-bb9d-4b1b-991e-d903aa2ad566', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-05 06:41:08.659583+00', '2025-06-05 06:41:34.486878+00', '2025-06-05T07:40:00', '2025-06-05T07:41:00', '2025-06-05T08:00:00'),
	('4b5a4834-808b-4582-84bd-8c4e4e4f7f7f', '5cd73045-8fb5-42dc-bacd-20408a628e94', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-11 15:21:04.34107+00', '2025-06-11 15:21:04.34107+00', '2025-06-11T16:20:00', '2025-06-11T16:21:00', '2025-06-11T16:35:00'),
	('f76803f3-a829-4734-9a06-a2a4fde56552', '5cd73045-8fb5-42dc-bacd-20408a628e94', '14446938-25cd-4655-ad84-dbb7db871f28', '296edb55-91eb-4d73-aa43-54840cbbf20c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '99d8db21-2c14-4f8f-8e54-54fc81004997', 'completed', '2025-06-11 15:48:30.775813+00', '2025-06-11 15:49:06.999645+00', '16:47', '16:48', '17:15'),
	('9e6c5f23-a237-4e78-9340-b7a7fa109b50', '5cd73045-8fb5-42dc-bacd-20408a628e94', '14446938-25cd-4655-ad84-dbb7db871f28', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'completed', '2025-06-11 15:53:02.172177+00', '2025-06-11 15:53:02.172177+00', '2025-06-11T16:52:00', '2025-06-11T16:53:00', '2025-06-11T17:17:00'),
	('8880fbcb-0969-4c3b-850f-057edb5a9c68', '5cd73045-8fb5-42dc-bacd-20408a628e94', '68e8e006-79dc-4d5f-aed0-20755d53403b', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', 'a8d3be01-4d46-41c1-b304-ab98610847e7', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'completed', '2025-06-11 15:53:40.018994+00', '2025-06-11 15:53:40.018994+00', '2025-06-11T16:53:00', '2025-06-11T16:54:00', '2025-06-11T17:23:00'),
	('ee82c36f-c044-4403-990d-d6f0ee5c2868', '5cd73045-8fb5-42dc-bacd-20408a628e94', 'be835d6f-62c6-48bf-ae5f-5257e097349b', '296edb55-91eb-4d73-aa43-54840cbbf20c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '99d8db21-2c14-4f8f-8e54-54fc81004997', 'completed', '2025-06-11 15:54:12.734747+00', '2025-06-11 15:54:12.734747+00', '2025-06-11T16:53:00', '2025-06-11T16:54:00', '2025-06-11T17:14:00');


--
-- Data for Name: shift_tasks_backup; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks_backup" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('724f2648-0b08-41a6-8321-91619e0dbabb', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'completed', '2025-05-23 07:24:46.89275+00', '2025-05-23 08:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('5e939454-7477-43e5-b5f3-65675d3e0ec7', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-23 06:24:46.89275+00', '2025-05-23 08:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('919ef224-d90e-4aac-8e52-dfa25ada730a', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', '0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('0e7dce68-352e-413a-a061-20fb11aa1ab0', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'f45a46c3-2240-462f-9895-494965ecd1a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-22 08:24:46.89275+00', '2025-05-22 09:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('4a06494e-1051-4006-b130-d72b4a6eebf1', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '516e8952-a09b-456b-926d-e78411490a6d', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-22 08:24:46.89275+00', '2025-05-22 10:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('74f81abd-0b5b-465d-a979-fa6dce4c276d', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '14446938-25cd-4655-ad84-dbb7db871f28', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'pending', '2025-05-22 12:24:46.89275+00', '2025-05-22 12:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('37ef35c9-6670-494d-871a-8eb16248720e', 'eca831e9-fa9f-4604-9526-0a6f70040f86', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'f45a46c3-2240-462f-9895-494965ecd1a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'pending', '2025-05-23 08:49:55.479887+00', '2025-05-23 08:50:01.281131+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('a5638fbf-2bfe-4805-be92-13d3bdab7be0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:54:22.695648+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('6e25558d-f989-49ce-8d40-c5b69f1af256', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:55:02.635556+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('8f16befe-a495-4b05-840d-cc077a569ad3', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-23 09:21:47.358281+00', '2025-05-23 09:21:47.358281+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('b57eb494-5648-4d1d-b783-aa48eced023a', 'e57acaf6-f171-42c5-958d-24ac48479180', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-23 14:35:11.683807+00', '2025-05-23 14:35:22.324033+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('1b91132f-6967-47a1-9b13-7d020244f6e6', 'e57acaf6-f171-42c5-958d-24ac48479180', '0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', '786d6d23-69b9-433e-92ed-938806cb10a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-23 14:38:42.170724+00', '2025-05-23 14:38:50.047597+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('ded0260e-9b51-4554-beb0-70e6bdf39b32', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'f45a46c3-2240-462f-9895-494965ecd1a8', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-24 07:41:55.150134+00', '2025-05-24 07:41:55.150134+00', '2025-05-24 07:41:55.025+00', '2025-05-24 07:42:55.025+00', '2025-05-24 08:01:55.025+00'),
	('9f9e0389-b2cb-4a87-a05b-b70c31459283', 'a124a872-d2d7-4324-b88a-780f82796906', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-24 08:26:33.109324+00', '2025-05-24 08:26:33.109324+00', '2025-05-24 08:26:33.044+00', '2025-05-24 08:27:33.044+00', '2025-05-24 08:46:33.044+00'),
	('591b8b57-fce6-4b8e-922e-1252774f6039', 'a124a872-d2d7-4324-b88a-780f82796906', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-24 08:31:54.281264+00', '2025-05-24 08:31:54.281264+00', '2025-05-24 08:31:54.241+00', '2025-05-24 08:32:54.241+00', '2025-05-24 08:51:54.241+00'),
	('9557e947-094b-42c3-ab99-4078c02672f6', 'a124a872-d2d7-4324-b88a-780f82796906', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'completed', '2025-05-24 11:38:53.866848+00', '2025-05-24 11:38:53.866848+00', '2025-05-24 11:38:53.786+00', '2025-05-24 11:39:53.786+00', '2025-05-24 11:58:53.786+00'),
	('b2240b4c-9d10-48f3-b7e8-97972bed7ca5', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '786d6d23-69b9-433e-92ed-938806cb10a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-24 11:40:04.592475+00', '2025-05-24 11:40:04.592475+00', '2025-05-24 11:40:04.499+00', '2025-05-24 11:41:04.499+00', '2025-05-24 12:00:04.499+00'),
	('d369e166-cdd0-4dd0-a4c1-8b3966b36cbc', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', '532b14f0-042a-4ddf-bc7d-cb95ff298132', '786d6d23-69b9-433e-92ed-938806cb10a8', '831035d1-93e9-4683-af25-b40c2332b2fe', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'completed', '2025-05-24 11:44:41.776885+00', '2025-05-24 11:44:41.776885+00', '2025-05-24 12:44:00+00', '2025-05-24 12:45:00+00', '2025-05-24 13:04:00+00'),
	('888222cb-1712-48dc-8b83-ae7cf10be5f1', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', 'e6068d5d-4bc5-4358-8bae-ed23759dc733', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-24 11:46:19.958128+00', '2025-05-24 11:46:19.958128+00', '2025-05-24 12:46:00+00', '2025-05-24 12:47:00+00', '2025-05-24 13:06:00+00'),
	('81a498e7-d3a2-40f7-8b98-1dd90d9d3a94', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', '14446938-25cd-4655-ad84-dbb7db871f28', '786d6d23-69b9-433e-92ed-938806cb10a8', '8c80c97d-010e-455e-bd7f-68dfccc27043', '831035d1-93e9-4683-af25-b40c2332b2fe', 'pending', '2025-05-24 11:59:45.542291+00', '2025-05-24 11:59:45.542291+00', '2025-05-24 12:59:00+00', '2025-05-24 13:00:00+00', '2025-05-24 13:19:00+00'),
	('6c5c9af5-1445-4da6-8786-b9672940cf9b', '0a0e958b-fe1a-4b28-96ba-cead157a49e5', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-24 12:01:54.700136+00', '2025-05-24 12:01:54.700136+00', '2025-05-24 13:01:00+00', '2025-05-24 13:02:00+00', '2025-05-24 13:21:00+00'),
	('58b9596f-48ab-464b-99c4-755bbd3b8b76', '0a0e958b-fe1a-4b28-96ba-cead157a49e5', 'e6068d5d-4bc5-4358-8bae-ed23759dc733', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-24 12:03:36.890857+00', '2025-05-24 12:03:36.890857+00', '2025-05-24 13:03:00+00', '2025-05-24 13:04:00+00', '2025-05-24 13:23:00+00');


--
-- Data for Name: staff_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_service_assignments" ("id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at", "shift_type") VALUES
	('e4a761cc-ad70-4925-8295-35c3fec29cc4', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_night'),
	('f864cc63-5b10-4679-8355-1c1bde5ffda0', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '20:00:00', '04:00:00', '#FBBC05', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_night'),
	('2c67f62c-5bf4-4805-9ac3-e5e5a451bd85', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_night'),
	('f9596013-1567-4c31-ae8e-ebb8737e0802', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_night'),
	('a8445e2f-ded7-45dd-a696-6b5b257764ad', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 06:50:10.906802+00', '2025-05-26 09:03:53.478545+00', 'weekend_day'),
	('56356547-809d-4c8f-9bbd-bd78398d1d7a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-26 09:04:19.954505+00', 'weekend_day'),
	('e3eab35f-e5b5-4001-a8f5-733314f7587e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 06:50:10.906802+00', '2025-05-26 10:12:24.468889+00', 'week_day'),
	('be438b48-ecae-48ac-a9ff-b63a7f45a061', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-26 10:16:55.703084+00', 'week_day');


--
-- Data for Name: support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_service_porter_assignments" ("id", "support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('ec6e6a94-b776-4bca-97af-09168c4b6354', '56356547-809d-4c8f-9bbd-bd78398d1d7a', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:58:00', '22:58:00', '2025-05-26 09:04:20.014261+00', '2025-05-26 09:04:20.014261+00'),
	('d988cc25-9301-41b1-bcb1-7876d68fa11b', 'e3eab35f-e5b5-4001-a8f5-733314f7587e', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-26 10:12:24.52429+00', '2025-05-26 10:12:24.52429+00'),
	('a68dbdbc-95f0-4e0f-a85e-34b852f1a6ef', 'be438b48-ecae-48ac-a9ff-b63a7f45a061', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-26 10:16:55.773306+00', '2025-05-26 10:16:55.773306+00');


--
-- Data for Name: task_item_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_item_department_assignments" ("id", "task_item_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ca6ab4d5-30dc-4cc9-8430-d5869da60a2d', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', true, false, '2025-05-24 15:21:51.189039+00'),
	('0d5d2df0-cc4d-4a68-829a-53fa3304c1e5', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', '969a27a7-f5e5-4c23-b018-128aa2000b97', true, false, '2025-05-24 15:22:08.265118+00'),
	('1c92bb0d-1130-4e11-bf56-b9bfc1f6a49d', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', true, false, '2025-05-27 16:10:54.167911+00'),
	('c8ad9fba-bfa4-474a-b337-66d537d9f89f', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', true, false, '2025-06-05 06:40:40.933013+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ceaa8539-8fd6-4954-8c00-2f8aea4bb3a6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '9056ee14-242b-4208-a87d-fc59d24d442c', false, true, '2025-05-24 12:33:59.810318+00'),
	('100f3cf6-3d37-4e48-90f3-c01b7874856b', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', true, false, '2025-05-24 15:23:36.64394+00'),
	('54743734-1466-4d1d-a90b-c01061983517', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'acb46743-a8c8-4cf5-bc85-4b9480f1862e', true, false, '2025-05-29 17:55:54.943147+00'),
	('c1c324a0-a75c-4df6-89a9-e42ad6ccaca4', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '81c30d93-8712-405c-ac5e-509d48fd9af9', true, false, '2025-06-11 16:31:16.04678+00'),
	('1a2da4ce-5545-49ad-9344-173efb9b5a9c', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', false, true, '2025-06-11 16:31:16.04678+00');


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

RESET ALL;
