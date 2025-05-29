

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
    
    -- Insert into shift_area_cover_assignments
    INSERT INTO shift_area_cover_assignments (
      shift_id, department_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_area_assignment.department_id, r_area_assignment.start_time, 
      r_area_assignment.end_time, r_area_assignment.color
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
    
    -- Insert into shift_support_service_assignments
    INSERT INTO shift_support_service_assignments (
      shift_id, service_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_service_assignment.service_id, r_service_assignment.start_time, 
      r_service_assignment.end_time, r_service_assignment.color
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
      v_debug_info := v_debug_info || E'\n  Processing service porter assignment: ' || r_service_porter.id;
      
      BEGIN
        INSERT INTO shift_support_service_porter_assignments (
          shift_support_service_assignment_id, porter_id, start_time, end_time
        ) VALUES (
          v_service_cover_assignment_id, r_service_porter.porter_id, 
          r_service_porter.start_time, r_service_porter.end_time
        );
        
        -- Add to debug info
        v_debug_info := v_debug_info || E'\n  Created service porter assignment for porter_id: ' || r_service_porter.porter_id;
      EXCEPTION WHEN OTHERS THEN
        -- Log the error but continue processing
        v_debug_info := v_debug_info || E'\n  ERROR inserting service porter assignment: ' || SQLERRM;
      END;
    END LOOP;
  END LOOP;
  
  -- Log the debug info to the PostgreSQL log
  RAISE NOTICE '%', v_debug_info;
  
EXCEPTION WHEN OTHERS THEN
  -- Log the error and debug info
  RAISE EXCEPTION 'Error in copy_defaults_to_shift: %, Debug info: %', SQLERRM, v_debug_info;
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
    CONSTRAINT "default_area_cover_assignments_shift_type_check" CHECK ((("shift_type")::"text" = ANY ((ARRAY['week_day'::character varying, 'week_night'::character varying, 'weekend_day'::character varying, 'weekend_night'::character varying])::"text"[])))
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
    CONSTRAINT "default_service_cover_assignments_shift_type_check" CHECK ((("shift_type")::"text" = ANY ((ARRAY['week_day'::character varying, 'week_night'::character varying, 'weekend_day'::character varying, 'weekend_night'::character varying])::"text"[])))
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


CREATE TABLE IF NOT EXISTS "public"."departments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "building_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_frequent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0
);


ALTER TABLE "public"."departments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
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
    "updated_at" timestamp with time zone DEFAULT "now"()
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
    "updated_at" timestamp with time zone DEFAULT "now"()
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



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_building_id_fkey" FOREIGN KEY ("building_id") REFERENCES "public"."buildings"("id") ON DELETE CASCADE;



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



GRANT ALL ON TABLE "public"."departments" TO "anon";
GRANT ALL ON TABLE "public"."departments" TO "authenticated";
GRANT ALL ON TABLE "public"."departments" TO "service_role";



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
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-05-28 15:10:25.95703+00', 0),
	('23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Portland Building', NULL, '2025-05-24 15:33:42.930237+00', '2025-05-28 15:10:25.95703+00', 10),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Werneth House', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-05-28 15:10:25.95703+00', 20),
	('d4d0bf79-eb71-477e-9d06-03159039e425', 'New Fountain House', NULL, '2025-05-24 12:20:27.560098+00', '2025-05-28 15:10:25.95703+00', 30),
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ladysmith Building', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-28 15:10:25.95703+00', 40),
	('e85c40e7-6f29-4e22-9787-6ed289c36429', 'Charlesworth Building', NULL, '2025-05-24 12:20:54.129832+00', '2025-05-28 15:10:25.95703+00', 50),
	('e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Bereavement Centre', NULL, '2025-05-24 15:12:37.764027+00', '2025-05-28 15:10:25.95703+00', 70),
	('69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Unit', NULL, '2025-05-24 15:31:30.919629+00', '2025-05-28 15:10:25.95703+00', 80),
	('e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal Unit', NULL, '2025-05-24 15:34:16.907485+00', '2025-05-28 15:10:25.95703+00', 90),
	('20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', NULL, '2025-05-27 15:49:56.650867+00', '2025-05-28 15:10:25.95703+00', 100),
	('abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Stores', NULL, '2025-05-29 08:52:06.678532+00', '2025-05-29 08:52:06.678532+00', 0);


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at", "sort_order") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 41', true, '2025-05-22 10:30:30.870153+00', '2025-05-28 12:25:54.280198+00', 10),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-05-28 13:28:50.222969+00', 10),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 40', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 20),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Library', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 30),
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', false, '2025-05-22 10:41:18.749919+00', '2025-05-28 09:40:45.973966+00', 50),
	('9056ee14-242b-4208-a87d-fc59d24d442c', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Pathology Lab', false, '2025-05-24 12:20:41.049859+00', '2025-05-28 09:40:45.973966+00', 70),
	('2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'NICU', false, '2025-05-24 12:21:01.329031+00', '2025-05-28 09:40:45.973966+00', 80),
	('6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 27', false, '2025-05-24 15:04:56.615271+00', '2025-05-28 09:40:45.973966+00', 100),
	('fa9e4d42-8282-42f8-bfd4-87691e20c7ed', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Ward', false, '2025-05-24 15:05:14.044021+00', '2025-05-28 09:40:45.973966+00', 110),
	('9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 30 (HCU)', false, '2025-05-24 15:05:26.651408+00', '2025-05-28 09:40:45.973966+00', 120),
	('c24a3784-6a06-469f-a764-49621f2d88d3', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 31', false, '2025-05-24 15:05:37.494475+00', '2025-05-28 09:40:45.973966+00', 130),
	('8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'IAU', false, '2025-05-24 15:05:46.603744+00', '2025-05-28 09:40:45.973966+00', 140),
	('6dc82d06-d4d2-4824-9a83-d89b583b7554', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'SDEC', false, '2025-05-24 15:05:53.620867+00', '2025-05-28 09:40:45.973966+00', 150),
	('a8d3be01-4d46-41c1-b304-ab98610847e7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Vasular Studies', false, '2025-05-24 15:06:04.488647+00', '2025-05-28 09:40:45.973966+00', 160),
	('1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'A+E (ED)', false, '2025-05-24 15:06:24.428146+00', '2025-05-28 09:40:45.973966+00', 170),
	('f9d3bbce-8644-4075-8b80-457777f6d16c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Ground Floor', false, '2025-05-24 15:06:39.563069+00', '2025-05-28 09:40:45.973966+00', 180),
	('8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Lower Ground Floor', false, '2025-05-24 15:06:52.499906+00', '2025-05-28 09:40:45.973966+00', 190),
	('42c2b3ab-f68d-429c-9675-3c79ff0ed222', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Ultrasound', false, '2025-05-24 15:07:04.431723+00', '2025-05-28 09:40:45.973966+00', 200),
	('35c73844-b511-423e-996c-5328ef21fedd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Clinics A-F', false, '2025-05-24 15:07:14.550747+00', '2025-05-28 09:40:45.973966+00', 210),
	('7295def1-1827-46dc-a443-a7aa7bf85b52', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Yellow Suite', false, '2025-05-24 15:07:27.863388+00', '2025-05-28 09:40:45.973966+00', 220),
	('f7c99832-60d1-42ee-8d35-0620a38f1e5d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Blue Suite', false, '2025-05-24 15:07:36.0704+00', '2025-05-28 09:40:45.973966+00', 230),
	('465893b5-6ab8-4776-bdbd-fd3c608ab966', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Swan Room', false, '2025-05-24 15:07:48.317926+00', '2025-05-28 09:40:45.973966+00', 240),
	('ac2333d2-0b37-4924-a039-478caf702fbd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s O+A', false, '2025-05-24 15:08:31.112268+00', '2025-05-28 09:40:45.973966+00', 260),
	('7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Day Surgery', false, '2025-05-24 15:09:06.573728+00', '2025-05-28 09:40:45.973966+00', 270),
	('4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Endoscopy Unit', false, '2025-05-24 15:09:18.185641+00', '2025-05-28 09:40:45.973966+00', 280),
	('c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'POU', false, '2025-05-24 15:09:37.760662+00', '2025-05-28 09:40:45.973966+00', 290),
	('f7525622-cd84-4c8c-94bf-b0428008b9c3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Frailty', false, '2025-05-24 15:10:12.266212+00', '2025-05-28 09:40:45.973966+00', 300),
	('36e599c5-89b2-4d50-b7df-47d5d1959ca4', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Surgical Hub', false, '2025-05-24 15:10:26.062318+00', '2025-05-28 09:40:45.973966+00', 310),
	('19b02bca-1dc6-4d00-b04d-a7e141a04870', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Plaster Room', false, '2025-05-24 15:10:32.921441+00', '2025-05-28 09:40:45.973966+00', 320),
	('76753b4b-ae1e-4477-a042-8deaab558e7b', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Discharge Lounge', false, '2025-05-24 15:11:40.525042+00', '2025-05-28 09:40:45.973966+00', 340),
	('0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 44', false, '2025-05-24 15:11:55.713923+00', '2025-05-28 09:40:45.973966+00', 360),
	('569e9211-d394-4e93-ba3e-34ad20d98af4', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 45', false, '2025-05-24 15:12:01.01766+00', '2025-05-28 09:40:45.973966+00', 370),
	('0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 46', false, '2025-05-24 15:12:07.981632+00', '2025-05-28 09:40:45.973966+00', 380),
	('99d8db21-2c14-4f8f-8e54-54fc81004997', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Rose Cottage', false, '2025-05-24 15:12:49.940045+00', '2025-05-28 09:40:45.973966+00', 390),
	('87a21a43-fe29-448f-9c08-b4d94226ad3f', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Infection Control', false, '2025-05-24 15:13:12.738948+00', '2025-05-28 09:40:45.973966+00', 400),
	('60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Switch', false, '2025-05-24 15:13:28.133871+00', '2025-05-28 09:40:45.973966+00', 410),
	('c06cd3c4-8993-4e7b-b198-a7fda4ede658', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Estates Management', false, '2025-05-24 15:13:37.481503+00', '2025-05-28 09:40:45.973966+00', 420),
	('a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'CDS (Acorn Birth Centre)', false, '2025-05-24 15:14:21.560252+00', '2025-05-28 09:40:45.973966+00', 430),
	('571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Womens Health', false, '2025-05-24 15:14:53.225063+00', '2025-05-28 09:40:45.973966+00', 440),
	('23199491-fe75-4c33-9cc8-1c86070cf0d1', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Triage', false, '2025-05-24 15:15:20.429518+00', '2025-05-28 09:40:45.973966+00', 450),
	('c0a07de6-b201-441b-a1fb-2b2ae9a95ac1', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Reception', false, '2025-05-24 15:16:21.942089+00', '2025-05-28 09:40:45.973966+00', 460),
	('bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Transfusion', false, '2025-05-24 15:20:33.127806+00', '2025-05-28 09:40:45.973966+00', 470),
	('969a27a7-f5e5-4c23-b018-128aa2000b97', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Bed Store', false, '2025-05-24 15:21:21.166917+00', '2025-05-28 09:40:45.973966+00', 480),
	('5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Mattress Store', false, '2025-05-24 15:21:31.144781+00', '2025-05-28 09:40:45.973966+00', 490),
	('9dae2f86-2058-4c9c-a428-76f5648553d3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'North Theatres', false, '2025-05-24 15:24:43.214387+00', '2025-05-28 09:40:45.973966+00', 500),
	('07e2b454-88ee-4d6a-9d75-a6ffa39bd241', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'South Theatres', false, '2025-05-24 15:24:51.854136+00', '2025-05-28 09:40:45.973966+00', 510),
	('d82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'MRI', false, '2025-05-24 15:25:16.973586+00', '2025-05-28 09:40:45.973966+00', 530),
	('df3d8d2a-dee5-4a21-a362-401236a2a1cb', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Pharmacy', false, '2025-05-24 15:30:28.871857+00', '2025-05-28 09:40:45.973966+00', 540),
	('943915e4-6818-4890-b395-a8272718eaf7', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford One', false, '2025-05-24 15:31:43.707094+00', '2025-05-28 09:40:45.973966+00', 550),
	('0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Two', false, '2025-05-24 15:31:53.020936+00', '2025-05-28 09:40:45.973966+00', 560),
	('1cac53b0-f370-4a13-95ca-f4cfd85dd197', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Ground', false, '2025-05-24 15:32:00.795352+00', '2025-05-28 09:40:45.973966+00', 570),
	('55f54692-d1ee-4047-bace-ff31744d2bc7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'FM Corridor', false, '2025-05-24 15:32:36.1272+00', '2025-05-28 09:40:45.973966+00', 580),
	('270df887-a13f-4004-a58d-9cec125b8da1', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Kitchens', false, '2025-05-24 15:32:43.567186+00', '2025-05-28 09:40:45.973966+00', 590),
	('06582332-0637-4d1a-b86e-876afe0bdc98', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Laundry', false, '2025-05-24 15:33:51.477397+00', '2025-05-28 09:40:45.973966+00', 600),
	('bf03ffcf-98d7-440e-adc1-5081e161c42d', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'I.T.', false, '2025-05-24 15:33:57.806509+00', '2025-05-28 09:40:45.973966+00', 610),
	('2368699a-6de0-45a9-ae25-dad26160cada', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Porters Lodge', false, '2025-05-24 15:34:07.683358+00', '2025-05-28 09:40:45.973966+00', 620),
	('ccb6bf8f-275c-4d24-8907-09b97cbe0eea', 'e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal', false, '2025-05-24 15:34:28.590837+00', '2025-05-28 09:40:45.973966+00', 630),
	('4c0821a2-dba8-48fe-9b8d-1c1ed6f8edea', '20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', false, '2025-05-27 15:50:07.946454+00', '2025-05-28 09:40:45.973966+00', 640),
	('1ae5c936-b74c-453e-a614-42b983416e40', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 43', true, '2025-05-24 15:11:49.971178+00', '2025-05-28 11:48:51.366161+00', 0),
	('3aa17398-7823-45ae-b76c-9b30d8509ce1', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 42', false, '2025-05-24 15:11:16.394196+00', '2025-05-28 12:25:57.780742+00', 10),
	('dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s Unit', true, '2025-05-24 15:08:15.838239+00', '2025-05-28 13:28:50.222969+00', 0),
	('5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'CT Department', false, '2025-05-24 15:25:11.218374+00', '2025-05-28 15:11:27.305929+00', 520),
	('acb46743-a8c8-4cf5-bc85-4b9480f1862e', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Stores', false, '2025-05-29 08:52:15.626457+00', '2025-05-29 08:52:15.626457+00', 0);


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id", "porter_type") VALUES
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'Martin', 'Smith', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-05-22 16:38:43.142566+00', NULL, 'shift'),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'Martin', 'Fearon', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-05-22 16:38:53.581199+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'shift'),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'Chris', 'Chrombie', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-05-22 16:39:03.319212+00', NULL, 'shift'),
	('a9d969e3-d449-4005-a679-f63be07c6872', 'Luke', 'Clements', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-05-22 16:39:16.282662+00', NULL, 'shift'),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'Porter', 'Four', 'porter', '2025-05-23 14:15:42.030594+00', '2025-05-23 14:15:42.030594+00', NULL, 'shift'),
	('2e74429e-2aab-4bed-a979-6ccbdef74596', 'Porter', 'Six', 'porter', '2025-05-24 15:27:50.974195+00', '2025-05-24 15:27:50.974195+00', NULL, 'shift'),
	('ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', 'Porter', 'Seven', 'porter', '2025-05-24 15:28:02.842334+00', '2025-05-24 15:28:02.842334+00', NULL, 'shift'),
	('bf79faf6-fb3e-4780-841e-63a4a67a5b77', 'Porter', 'Nine', 'porter', '2025-05-24 15:28:15.192437+00', '2025-05-24 15:28:15.192437+00', NULL, 'shift'),
	('8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'Porter', 'Ten', 'porter', '2025-05-24 15:28:21.287841+00', '2025-05-24 15:28:21.287841+00', NULL, 'shift'),
	('7c20aec3-bf78-4ef9-b35e-429e41ac739b', 'Porter', 'Eleven', 'porter', '2025-05-24 15:28:35.013201+00', '2025-05-24 15:28:35.013201+00', NULL, 'shift'),
	('2524b1c5-45e1-4f15-bf3b-984354f22cdc', 'Porter', 'Thirteen', 'porter', '2025-05-24 15:28:50.433536+00', '2025-05-24 15:28:50.433536+00', NULL, 'shift'),
	('f304fa99-8e00-48d0-a616-d156b0f7484d', 'Porter', 'Fourteen', 'porter', '2025-05-24 15:29:00.080381+00', '2025-05-24 15:29:00.080381+00', NULL, 'shift'),
	('4fb21c6f-2f5b-4f6e-b727-239a3391092a', 'Porter', 'Fifteen', 'porter', '2025-05-24 15:29:10.541023+00', '2025-05-24 15:29:10.541023+00', NULL, 'shift'),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'Porter', 'Five', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-24 15:29:23.335292+00', NULL, 'shift'),
	('12055968-78d3-4404-a05f-10e039217936', 'Porter', 'One', 'porter', '2025-05-24 15:35:19.897285+00', '2025-05-24 15:35:19.897285+00', NULL, 'shift'),
	('8b3b3e97-ea54-4c40-884b-04d3d24dbe23', 'Porter', 'Sixteen', 'porter', '2025-05-24 15:46:43.723804+00', '2025-05-24 15:46:43.723804+00', NULL, 'shift'),
	('e55b1013-7e79-4e38-913e-c53de591f85c', 'Porter', 'Eighteen', 'porter', '2025-05-24 15:47:03.70938+00', '2025-05-24 15:47:03.70938+00', NULL, 'shift'),
	('69766d05-49d7-4e7c-8734-e3dc8949bf91', 'Porter', 'Twenty', 'porter', '2025-05-24 15:47:22.720752+00', '2025-05-24 15:47:22.720752+00', NULL, 'shift'),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'Porter', 'Two', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-25 09:56:14.035659+00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'shift'),
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'Porter', 'Three', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-27 16:38:58.177879+00', NULL, 'relief'),
	('78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', 'Porter', 'Eight', 'porter', '2025-05-24 15:28:08.999647+00', '2025-05-27 16:43:40.140614+00', NULL, 'relief'),
	('4e87f01b-5196-47c4-b424-4cfdbe7fb385', 'Porter', 'Nineteen', 'porter', '2025-05-24 15:47:12.658077+00', '2025-05-27 16:50:36.039303+00', NULL, 'relief'),
	('8eaa9194-b164-4cb4-a15c-956299ff28c5', 'Porter', 'Seventeen', 'porter', '2025-05-24 15:46:56.110419+00', '2025-05-27 16:50:41.208203+00', NULL, 'relief'),
	('ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'Porter', 'Twelve', 'porter', '2025-05-24 15:28:41.635621+00', '2025-05-27 16:50:47.226487+00', NULL, 'relief'),
	('1aaab277-ecf2-40dd-a764-eaaf8af7615b', 'Post', 'Porter 1', 'porter', '2025-05-28 15:36:02.205704+00', '2025-05-28 15:36:02.205704+00', NULL, 'shift'),
	('c965e4e3-e132-43f0-94ce-1b41d33a9f05', 'Post', 'Porter 2', 'porter', '2025-05-28 15:36:13.899635+00', '2025-05-28 15:36:13.899635+00', NULL, 'shift'),
	('04947318-f8a7-4eea-8044-5219c5e907fc', 'Post', 'Porter 3', 'porter', '2025-05-28 15:36:24.156976+00', '2025-05-28 15:36:24.156976+00', NULL, 'shift'),
	('4377dd38-cf15-4de2-8347-0461ba6afff5', 'Laundry', 'Porter 1', 'porter', '2025-05-28 15:36:45.727912+00', '2025-05-28 15:36:45.727912+00', NULL, 'shift'),
	('f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', 'Laundry', 'Porter 2', 'porter', '2025-05-28 15:36:52.317877+00', '2025-05-28 15:36:52.317877+00', NULL, 'shift'),
	('56d5a952-a958-41c5-aa28-bd42e06720c8', 'Med Recs', 'Porter 1', 'porter', '2025-05-28 15:37:14.70567+00', '2025-05-28 15:37:14.70567+00', NULL, 'shift'),
	('b96a6ffa-6f54-4eab-a1c8-5c65dc7223da', 'Med Recs', 'Porter 2', 'porter', '2025-05-28 15:37:22.975093+00', '2025-05-28 15:37:22.975093+00', NULL, 'shift'),
	('296edb55-91eb-4d73-aa43-54840cbbf20c', 'Pharmacy', 'Porter 1', 'porter', '2025-05-28 15:37:34.781762+00', '2025-05-28 15:37:34.781762+00', NULL, 'shift'),
	('c3052ff8-8339-4e02-b4ed-efee9365e7c2', 'District', 'Driver 1', 'porter', '2025-05-28 15:37:56.707711+00', '2025-05-28 15:37:56.707711+00', NULL, 'shift'),
	('80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', 'District', 'Driver 2', 'porter', '2025-05-28 15:38:06.309697+00', '2025-05-28 15:38:06.309697+00', NULL, 'shift'),
	('e9cf3a23-c94a-409b-aa71-d42602e54068', 'Adhoc', 'Porter 1', 'porter', '2025-05-28 15:38:29.329131+00', '2025-05-28 15:38:29.329131+00', NULL, 'shift'),
	('6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', 'Adhoc', 'Porter 2', 'porter', '2025-05-28 15:38:38.608871+00', '2025-05-28 15:38:38.608871+00', NULL, 'shift'),
	('83fdb588-e638-47ae-b726-51f83a4378c7', 'External Waste', 'Porter 1', 'porter', '2025-05-28 15:39:06.096334+00', '2025-05-28 15:39:06.096334+00', NULL, 'shift'),
	('1a21db6c-9a35-48ca-a3b0-06284bec8beb', 'External Waste', 'Porter 2', 'porter', '2025-05-28 15:39:12.414354+00', '2025-05-28 15:39:12.414354+00', NULL, 'shift'),
	('c162858c-9815-43e3-9bcb-0c709bd8eef0', 'A+E', 'Porter 1', 'porter', '2025-05-28 15:39:52.203155+00', '2025-05-28 15:39:52.203155+00', NULL, 'shift'),
	('6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', 'A+E', 'Porter 2', 'porter', '2025-05-28 15:40:00.100404+00', '2025-05-28 15:40:00.100404+00', NULL, 'shift'),
	('2ef290c6-6c61-4d37-be45-d08ae6afc097', 'A+E', 'Porter 3', 'porter', '2025-05-28 15:40:14.777056+00', '2025-05-28 15:40:14.777056+00', NULL, 'shift'),
	('050fa6e6-477b-4f83-aae4-3e13c954ca6a', 'Xray', 'Porter 1', 'porter', '2025-05-28 15:40:45.206052+00', '2025-05-28 15:40:45.206052+00', NULL, 'shift'),
	('cb50a5b2-3812-4688-b1f6-ccf0ab7626b6', 'Xray', 'Porter 2', 'porter', '2025-05-28 15:40:56.522945+00', '2025-05-28 15:40:56.522945+00', NULL, 'shift');


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

INSERT INTO "public"."default_area_cover_assignments" ("id", "department_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('84a7eb2b-66ad-4883-a6ef-e78bedff694a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:29.515957+00', '2025-05-28 15:13:29.515957+00'),
	('2f7b79ab-e3fd-4745-9095-633bc97a05cc', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:47.240244+00', '2025-05-28 15:13:47.240244+00'),
	('62d6ae7f-b3ef-4bd0-ad5a-c4a0ab46c5fa', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:50.992166+00', '2025-05-28 15:13:50.992166+00'),
	('de8f136e-deeb-494b-bae9-54cf7a4ea5bf', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:14:15.321389+00', '2025-05-28 15:14:15.321389+00'),
	('ed182065-4e96-40cb-9b41-96f7cdebb907', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:20:32.081824+00', '2025-05-28 15:20:32.081824+00'),
	('9ccff924-1281-42ac-b712-7989bfe50c6d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:21:05.371703+00', '2025-05-28 15:21:05.371703+00'),
	('4b07ffe6-9df3-4e93-ba02-ecd8607c65d3', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:21:24.017899+00', '2025-05-28 15:21:24.017899+00'),
	('55a9e1d1-b177-4fc8-ba8d-a1483bd58e40', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'week_day', '11:00:00', '18:00:00', '#4285F4', '2025-05-28 15:05:10.786766+00', '2025-05-28 15:28:15.593036+00'),
	('d60ea4d0-7c69-412c-9dd1-aad01645e1dc', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:12:39.489353+00', '2025-05-28 15:28:28.662418+00'),
	('73fee5fd-ec48-4e53-9a6a-bb2cdad86311', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:13:17.977154+00', '2025-05-28 15:28:37.218234+00'),
	('5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:12:06.807373+00', '2025-05-28 15:28:53.008719+00'),
	('3a2ff90b-5523-4f5f-848d-3d8989c81981', 'f9d3bbce-8644-4075-8b80-457777f6d16c', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:11:59.336598+00', '2025-05-28 15:44:48.523906+00'),
	('d71c6999-f5ca-4108-a2e0-21c4afc008f5', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_day', '08:00:00', '20:00:00', '#f443b3', '2025-05-28 15:07:17.30595+00', '2025-05-29 09:11:13.851064+00');


--
-- Data for Name: default_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_porter_assignments" ("id", "default_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('9e1db356-7b2a-4c7d-9520-1817deade5ce', '3a2ff90b-5523-4f5f-848d-3d8989c81981', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-28 15:44:20.5444+00', '2025-05-28 15:44:48.629861+00'),
	('1c807446-176a-48ed-b9fb-82381265fe3e', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-28 15:42:23.038266+00', '2025-05-29 09:11:13.917832+00'),
	('979b52e3-ad15-4f2b-9479-4564dde9e8c0', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-28 15:42:23.103858+00', '2025-05-29 09:11:13.994079+00'),
	('844cfc29-af57-4653-ad87-8754111ae49b', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-28 15:43:02.208024+00', '2025-05-29 09:11:14.073792+00');


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

INSERT INTO "public"."default_service_cover_assignments" ("id", "service_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('ce4b641d-619d-4c1b-8c68-d9d850306492', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:14:07.575453+00', '2025-05-28 15:14:07.575453+00'),
	('57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:08:50.364355+00', '2025-05-28 15:15:16.496247+00'),
	('55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '26c0891b-56c0-4346-8d53-de906aaa64c2', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:46.235606+00', '2025-05-28 15:15:43.407796+00'),
	('557671ae-71a7-41f5-bbf7-7d74413e7c9a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:40.45798+00', '2025-05-28 15:16:02.806015+00'),
	('6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', 'ce940139-6ae7-49de-a62a-0d6ba9397928', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:33.377391+00', '2025-05-28 15:16:11.848824+00'),
	('8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '7cfa1ddf-61b0-489e-ad23-b924cf995419', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:07:52.088351+00', '2025-05-28 15:45:33.820507+00'),
	('aa1a61d1-e538-415a-a89d-9f568fc92adb', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:05:23.573715+00', '2025-05-28 15:50:06.957383+00'),
	('062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:57.826093+00', '2025-05-29 08:27:04.449116+00');


--
-- Data for Name: default_service_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_porter_assignments" ("id", "default_service_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('8c6b82d4-a0f9-4c51-863f-4ca7770764ab', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-28 15:45:33.930573+00', '2025-05-28 15:45:33.930573+00'),
	('3ba8fe20-02ff-43a5-9ffd-dc4af782869d', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-28 15:45:34.008349+00', '2025-05-28 15:45:34.008349+00'),
	('228fa1a0-fc85-4fe9-890c-c1ca206e9817', 'aa1a61d1-e538-415a-a89d-9f568fc92adb', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-28 15:48:59.181511+00', '2025-05-28 15:50:07.042265+00'),
	('9d0cc07c-0436-4a2c-8212-565ed998fd20', 'aa1a61d1-e538-415a-a89d-9f568fc92adb', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-28 15:50:07.090746+00', '2025-05-28 15:50:07.090746+00'),
	('9ce1eb46-4c11-45e4-8dd7-7d171d3866b4', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-28 15:47:47.769753+00', '2025-05-29 08:27:04.523514+00'),
	('d5e98312-99d1-4713-a6bc-de6540d3bdcc', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 08:27:04.593408+00', '2025-05-29 08:27:04.593408+00');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at") VALUES
	('be379e15-5712-454f-9c1a-e429358828ec', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-28 08:25:42.508+00', '2025-05-28 13:50:17.284+00', false, '2025-05-28 08:54:44.361316+00', '2025-05-28 13:50:17.545048+00'),
	('839b6adc-0b0d-4c92-bc14-7cd220308394', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-27 16:11:03.336+00', '2025-05-28 14:11:52.282+00', false, '2025-05-27 16:11:03.414036+00', '2025-05-28 14:11:52.408235+00'),
	('7e282dd3-0471-4202-9fe5-486a64309d1a', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-28 13:50:49.924+00', '2025-05-28 14:11:57.592+00', false, '2025-05-28 13:50:49.996722+00', '2025-05-28 14:11:57.694407+00'),
	('6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-28 14:07:53.523+00', '2025-05-28 14:14:04.148+00', false, '2025-05-28 14:07:53.648455+00', '2025-05-28 14:14:04.254756+00'),
	('acb1051e-087e-4ecf-90cc-f0f49ad61110', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-28 14:14:11.086+00', '2025-05-28 14:52:37.176+00', false, '2025-05-28 14:14:11.170075+00', '2025-05-28 14:52:37.306398+00'),
	('a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'week_day', '2025-05-28 15:30:11.621+00', '2025-05-28 15:34:34.263+00', false, '2025-05-28 15:30:11.819926+00', '2025-05-28 15:34:34.330452+00'),
	('dcf08f05-08b7-467e-9169-c4f94747e5d6', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-28 15:23:38.25+00', '2025-05-28 15:34:37.581+00', false, '2025-05-28 15:23:38.345653+00', '2025-05-28 15:34:37.646+00'),
	('c583b538-a3f2-43fe-bed3-5ec2a078c2db', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-28 15:05:41.269+00', '2025-05-28 15:34:40.777+00', false, '2025-05-28 15:05:41.346448+00', '2025-05-28 15:34:40.85795+00'),
	('e2ad7a21-f0b9-4a1b-84c0-ad11d2762c6d', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-28 15:04:15.676+00', '2025-05-28 15:34:44.725+00', false, '2025-05-28 15:04:15.776479+00', '2025-05-28 15:34:44.799099+00'),
	('45f5eef8-e933-4853-bfe5-a4916746cdd2', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-28 15:50:27.893+00', '2025-05-29 06:20:07.365+00', false, '2025-05-28 15:50:27.909307+00', '2025-05-29 06:20:07.504311+00'),
	('619f7fb8-02da-4e00-bcfc-c545603952fc', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-28 15:34:50.205+00', '2025-05-29 06:20:12.812+00', false, '2025-05-28 15:34:50.253646+00', '2025-05-29 06:20:12.958927+00'),
	('4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-29 06:40:27.139+00', '2025-05-29 06:53:41.409+00', false, '2025-05-29 06:40:27.262833+00', '2025-05-29 06:53:41.523952+00'),
	('f68f03e9-119d-4d29-9af8-87f751147b52', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-29 06:21:08.777+00', '2025-05-29 06:53:47.756+00', false, '2025-05-29 06:21:08.918092+00', '2025-05-29 06:53:47.880681+00'),
	('13e648a2-4857-4de4-903b-009644b0d6bc', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-29 06:53:53.435+00', '2025-05-29 09:11:43.753+00', false, '2025-05-29 06:53:53.531786+00', '2025-05-29 09:11:43.848523+00'),
	('58eb2384-c37d-423f-a568-cb98b757a16d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-29 08:26:34.308+00', '2025-05-29 09:11:47.883+00', false, '2025-05-29 08:26:34.45197+00', '2025-05-29 09:11:47.979042+00'),
	('206089d8-6208-4abf-a126-3d1fb00b3cae', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-29 09:11:27.613+00', '2025-05-29 09:11:55.667+00', false, '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:55.767001+00'),
	('91f2c868-aa7c-484a-9c15-2a425fd744fe', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-29 09:59:17.878+00', NULL, true, '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('ec565d4d-ed9d-4ed3-8529-5e3b17f75944', '839b6adc-0b0d-4c92-bc14-7cd220308394', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('b386e9be-003e-4c9d-994c-1e96f9e8c494', '839b6adc-0b0d-4c92-bc14-7cd220308394', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('7d91b744-d3d2-4df1-ab69-2d0cb8639997', '839b6adc-0b0d-4c92-bc14-7cd220308394', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('cb9b7aa7-6001-4264-b6fe-602549a4e78d', '839b6adc-0b0d-4c92-bc14-7cd220308394', 'c06cd3c4-8993-4e7b-b198-a7fda4ede658', '20:00:00', '04:00:00', '#4285F4', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('07f9762d-89e6-4997-85ed-b07ed6db0e4c', 'be379e15-5712-454f-9c1a-e429358828ec', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('23ed12b5-6d4d-4c47-a1c9-4c02982951b8', 'be379e15-5712-454f-9c1a-e429358828ec', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('21bc535a-a4a0-4f98-a5f7-e4b35a487b48', 'be379e15-5712-454f-9c1a-e429358828ec', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('f9b5c175-fd6e-406c-aa77-dbfa30efb294', 'be379e15-5712-454f-9c1a-e429358828ec', 'c06cd3c4-8993-4e7b-b198-a7fda4ede658', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('4f554384-4b37-4806-8f16-1d3c0e789bd9', '7e282dd3-0471-4202-9fe5-486a64309d1a', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('bfbc6bcc-fb4e-4a4d-8395-72ace00240cc', '7e282dd3-0471-4202-9fe5-486a64309d1a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('ad1814e1-fabb-4bc1-937c-3325ba90ac16', '7e282dd3-0471-4202-9fe5-486a64309d1a', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('2d0ce610-a18f-41ed-bb0b-a2cf93e10a90', '7e282dd3-0471-4202-9fe5-486a64309d1a', 'c06cd3c4-8993-4e7b-b198-a7fda4ede658', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('bd2e2a86-d335-4677-a4a9-ee30dd1b2bcf', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('8d86b881-cb43-4952-b29d-4e81f2527e10', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('dddad5f8-1373-4cd0-9ed2-fd98f4e1df41', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('7c0d4853-448a-4b3e-b56c-f6f16e8ab2a4', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'c06cd3c4-8993-4e7b-b198-a7fda4ede658', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('283992ed-fd91-4614-ae35-58df02899dbe', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('b1a84344-6152-4205-8eb2-516af0c22b3c', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('6f683e16-6a1d-4ed3-896d-a7f330ddc11e', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('f82ac481-84da-4531-83cf-625f3fb4bf4c', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', 'c06cd3c4-8993-4e7b-b198-a7fda4ede658', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('32978b99-fd9a-4f83-b3a0-658287ea616d', 'e2ad7a21-f0b9-4a1b-84c0-ad11d2762c6d', 'a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 15:04:27.607151+00', '2025-05-28 15:04:27.607151+00'),
	('32801254-29c7-4840-bd6d-301aa28340e9', 'c583b538-a3f2-43fe-bed3-5ec2a078c2db', '81c30d93-8712-405c-ac5e-509d48fd9af9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:05:41.346448+00', '2025-05-28 15:05:41.346448+00'),
	('18abccbf-5e0c-4caf-936f-3980f91a9abc', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '81c30d93-8712-405c-ac5e-509d48fd9af9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('0fbdbc36-4e12-415c-8125-7a610d5a4134', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('87675177-be7f-4609-b647-ca7963e58af5', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('5df45b1e-056e-41e6-a17a-6d9ca80c975c', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('a28ea3ca-3865-4436-9f9b-fae066269fc9', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('46b0b039-4a13-4c7c-a224-bbc388b739f6', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('a2519071-6cb0-4208-9a6a-cdcb30eebb13', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('5fae5f7b-2b19-4e7f-8e48-fb55151b220c', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('8725a7ec-ab5b-4fc7-8ffb-bc4c845d1abe', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('310e4b45-a380-4c81-ad94-ca541ce47b78', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('b85d9301-7f3b-45d9-9a90-fe1c301d1dc2', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('17a2410a-ec0e-418d-9075-1e750d90d2b1', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('54c2d03b-7d34-48eb-94c3-2098beb02cd7', '619f7fb8-02da-4e00-bcfc-c545603952fc', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('b78ba2d8-657d-4346-a5a9-f0dfa99ba77a', '619f7fb8-02da-4e00-bcfc-c545603952fc', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('abffda57-b3b5-427c-8b66-4e52ef62cd8b', '619f7fb8-02da-4e00-bcfc-c545603952fc', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('77dc673f-62fa-46c3-9dab-9f36c719e28e', '619f7fb8-02da-4e00-bcfc-c545603952fc', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('0886c342-ba5b-4896-b62c-80780fb5a33b', '619f7fb8-02da-4e00-bcfc-c545603952fc', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('3635619f-14ba-43ff-a9e6-8e3bcf72051d', '619f7fb8-02da-4e00-bcfc-c545603952fc', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('07595a2b-7f9b-42b1-8b0e-a0cdafcb0582', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('abfe8a0e-c962-4921-9e75-8248841b6773', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('424a096e-452d-4f84-a63f-55f75b315c90', '45f5eef8-e933-4853-bfe5-a4916746cdd2', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('322691dd-e106-4236-aa90-1ddce5f08d41', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('d4f7303f-c505-4fca-bda7-64a861079295', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('48b837e5-839a-4a7a-82b2-9dda53180647', '45f5eef8-e933-4853-bfe5-a4916746cdd2', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('0f0590d9-2497-4427-bc57-ca9c69df43f1', 'f68f03e9-119d-4d29-9af8-87f751147b52', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('85b14320-13c8-4793-80fb-31ad422b1407', 'f68f03e9-119d-4d29-9af8-87f751147b52', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('61f1e661-ca12-4799-b93b-2ca924b82aec', 'f68f03e9-119d-4d29-9af8-87f751147b52', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('a2da86bd-d475-493f-9498-683af1e37fe8', 'f68f03e9-119d-4d29-9af8-87f751147b52', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('d33621fc-0796-4e6a-be33-e6888cf05c1c', 'f68f03e9-119d-4d29-9af8-87f751147b52', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('028dbceb-e2ce-40d1-a67d-f31856a8c449', 'f68f03e9-119d-4d29-9af8-87f751147b52', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('0c655fa5-6cd2-4573-95e1-fb7b32e00f46', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('ab796e74-c531-41a1-b062-927c04378991', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('76194817-1f01-4d89-ab70-6fa76de5a0c8', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('91ea98bb-cab1-46ac-b66a-021ff3807c51', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('6981e9af-313b-4135-a8a2-bbc0829f1f7c', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('5958f218-ef98-4024-a507-47e9a1afcd30', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('d11c9782-36f3-4e58-af35-1973edbe6b8e', '13e648a2-4857-4de4-903b-009644b0d6bc', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('abc9a467-5e52-4577-99de-66b181ce9bd8', '13e648a2-4857-4de4-903b-009644b0d6bc', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('48f97dab-3d59-4c8d-9478-76210b179a94', '13e648a2-4857-4de4-903b-009644b0d6bc', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('bf3079fe-1a7d-4c7a-a6f0-a02e9167c157', '13e648a2-4857-4de4-903b-009644b0d6bc', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('c77e46aa-3b87-4189-8b03-36e0f1141d2f', '13e648a2-4857-4de4-903b-009644b0d6bc', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('f547ffb8-c1b3-4447-8044-0c0a772a5e22', '13e648a2-4857-4de4-903b-009644b0d6bc', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('fe1c7166-ccea-428d-9163-00ef5c67b16f', '58eb2384-c37d-423f-a568-cb98b757a16d', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('63d4d534-f945-4a2f-8f01-86c6042ed830', '58eb2384-c37d-423f-a568-cb98b757a16d', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('3b78d55c-77d6-40e4-ab78-e537217065f5', '58eb2384-c37d-423f-a568-cb98b757a16d', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('54f870d0-5159-49ec-afed-af0243ca5bfe', '58eb2384-c37d-423f-a568-cb98b757a16d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('ea103bb0-1d2d-499a-a530-40fa87abe97a', '58eb2384-c37d-423f-a568-cb98b757a16d', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('9d62d254-1d2d-4e63-917d-c6088c56acc1', '58eb2384-c37d-423f-a568-cb98b757a16d', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('03cd4486-82bf-4bdd-8fab-b2a339578fb8', '206089d8-6208-4abf-a126-3d1fb00b3cae', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('d99d0e8f-0dda-413d-abbd-e4fadb799693', '206089d8-6208-4abf-a126-3d1fb00b3cae', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('0cd43aa1-5b8d-436e-addf-0bb08d67f5e9', '206089d8-6208-4abf-a126-3d1fb00b3cae', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('2b4d92fe-0297-49e9-a7e1-daf15f992c6c', '206089d8-6208-4abf-a126-3d1fb00b3cae', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('28985517-1eac-4164-bc40-9bfd3a1427ca', '206089d8-6208-4abf-a126-3d1fb00b3cae', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('d6f68878-177c-40fd-bc1c-ae0e5eedb110', '206089d8-6208-4abf-a126-3d1fb00b3cae', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('810d6556-23ed-4345-8f95-4356c6fe82d3', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('890540ba-e31d-43b8-9d80-dcce462289b7', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('f802eb03-de6c-4ec5-8c29-1476a0bfaa40', '91f2c868-aa7c-484a-9c15-2a425fd744fe', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('802683fb-45e1-4625-9bd2-d99ca5f4628f', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('46759aef-7aa8-46c5-8ac0-680c364ada23', '91f2c868-aa7c-484a-9c15-2a425fd744fe', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('4fa4dc68-46c0-4815-9c98-b6e12c63bc00', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00');


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_porter_assignments" ("id", "shift_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('68445235-51db-4116-85db-e8b4e9e06b84', 'b386e9be-003e-4c9d-994c-1e96f9e8c494', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('45efa1c5-f4d2-4261-b7ae-27fd06a84668', 'b386e9be-003e-4c9d-994c-1e96f9e8c494', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:49:00', '20:49:00', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('e0a36a23-7b08-461a-87d7-6579bf4cab9f', 'cb9b7aa7-6001-4264-b6fe-602549a4e78d', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:12:00', '21:12:00', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('62978a6c-0931-4e2b-b465-1f400dade91e', '23ed12b5-6d4d-4c47-a1c9-4c02982951b8', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('ac3fce54-13a9-42f5-b1e8-1aaa41d6d6e0', '23ed12b5-6d4d-4c47-a1c9-4c02982951b8', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:49:00', '20:49:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('81f0cf50-5ceb-44c6-999c-9e0b3cdb2ad9', 'f9b5c175-fd6e-406c-aa77-dbfa30efb294', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:12:00', '21:12:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('abeb84ff-4145-4b8f-bb57-9d2a439c474c', 'bfbc6bcc-fb4e-4a4d-8395-72ace00240cc', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('f1dc596d-f15d-444d-ac04-4bbc8eeeeed3', 'bfbc6bcc-fb4e-4a4d-8395-72ace00240cc', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:49:00', '20:49:00', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('d9c7b620-5714-44cd-84c2-f962d29e036d', '2d0ce610-a18f-41ed-bb0b-a2cf93e10a90', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:12:00', '21:12:00', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('0c31748c-5b3b-437f-87f2-195c6343143c', '8d86b881-cb43-4952-b29d-4e81f2527e10', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('cf32e00a-247f-4cb3-a83a-23722571c91b', '8d86b881-cb43-4952-b29d-4e81f2527e10', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:49:00', '20:49:00', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('3140aa8e-2655-4ce9-a032-feae71f96434', '7c0d4853-448a-4b3e-b56c-f6f16e8ab2a4', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:12:00', '21:12:00', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('6b9d434c-5d98-46c3-aeb1-21f15f1f0af0', 'b1a84344-6152-4205-8eb2-516af0c22b3c', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('1f0af3a7-95ac-430c-8f65-79620ad3fb4b', 'b1a84344-6152-4205-8eb2-516af0c22b3c', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:49:00', '20:49:00', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('da0237e3-e94b-4e2e-8380-aad0efe0c81e', 'f82ac481-84da-4531-83cf-625f3fb4bf4c', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:12:00', '21:12:00', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('e6337448-d6e4-4ef9-b9c0-b5a76f91a408', '17a2410a-ec0e-418d-9075-1e750d90d2b1', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '06:00:00', '14:00:00', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('f9378075-0c2d-4949-a031-b978e43dd972', 'a2519071-6cb0-4208-9a6a-cdcb30eebb13', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '11:00:00', '18:00:00', '2025-05-28 15:31:01.437057+00', '2025-05-28 15:31:01.437057+00'),
	('337ab4dc-0589-409a-b377-eb23f4aa790a', '3635619f-14ba-43ff-a9e6-8e3bcf72051d', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '06:00:00', '14:00:00', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('478d16ff-b108-4769-b834-2d52fb8b505b', 'd4f7303f-c505-4fca-bda7-64a861079295', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('1d8a46e9-d3e5-4257-9c3d-b05c9ce3a4f9', 'd4f7303f-c505-4fca-bda7-64a861079295', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('856c856c-53d4-4799-874e-6b99abc786da', 'd4f7303f-c505-4fca-bda7-64a861079295', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('88ff237c-1a7a-4de1-9a0a-ea651359dc72', '48b837e5-839a-4a7a-82b2-9dda53180647', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('1b5faa4d-aecc-4408-9f87-84e8066fc320', 'd33621fc-0796-4e6a-be33-e6888cf05c1c', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('79cb924d-cf9d-4ef2-ae8f-a95e90389ed8', 'd33621fc-0796-4e6a-be33-e6888cf05c1c', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('e4c369be-2a38-4f57-bc19-28f4cc5ecfc1', 'd33621fc-0796-4e6a-be33-e6888cf05c1c', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('4f66f132-8767-4fa1-91b9-c5f4a240f581', '028dbceb-e2ce-40d1-a67d-f31856a8c449', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('f0e09758-642a-4fbb-bf6a-58601bf55465', '6981e9af-313b-4135-a8a2-bbc0829f1f7c', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('b4c88129-9bed-480a-88b6-491ce88771a7', '6981e9af-313b-4135-a8a2-bbc0829f1f7c', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('c03431ce-6937-480a-ae08-e8f0d6c81a5a', '6981e9af-313b-4135-a8a2-bbc0829f1f7c', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('300b47b4-7fa7-4641-ba9b-59c4c1593f18', '5958f218-ef98-4024-a507-47e9a1afcd30', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('56404a85-101e-4779-8f93-94105a8fe7e2', 'c77e46aa-3b87-4189-8b03-36e0f1141d2f', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('4d0a7c61-ae58-47f7-a5bf-f43b65d10f37', 'c77e46aa-3b87-4189-8b03-36e0f1141d2f', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('a1f7c8f3-57a7-4d09-bb94-0b1fd4758448', 'c77e46aa-3b87-4189-8b03-36e0f1141d2f', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('ce8ae398-14b7-48b3-9600-9794ce68889c', 'f547ffb8-c1b3-4447-8044-0c0a772a5e22', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('b8504377-e8cc-42a7-84d2-885a5999558c', 'ea103bb0-1d2d-499a-a530-40fa87abe97a', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('d37a719d-a366-47a1-bf5c-7d0b978df2bb', 'ea103bb0-1d2d-499a-a530-40fa87abe97a', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('1bf6158c-3ca2-47d8-9b61-140b2b0d0339', 'ea103bb0-1d2d-499a-a530-40fa87abe97a', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('ae69d432-ec15-411e-b34d-5b25768160e2', '9d62d254-1d2d-4e63-917d-c6088c56acc1', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('78d7bbb4-889f-479d-a78e-f0b31e96b976', '28985517-1eac-4164-bc40-9bfd3a1427ca', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('f00c7b74-c393-4a5c-94a2-a0c796e69103', 'd6f68878-177c-40fd-bc1c-ae0e5eedb110', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('f2c533e3-6e81-4262-9d7b-e09c8dfea315', 'd6f68878-177c-40fd-bc1c-ae0e5eedb110', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('f271ae4a-5104-4283-9ec7-9af403f2b116', 'd6f68878-177c-40fd-bc1c-ae0e5eedb110', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('28ba0f78-b183-47a5-836f-bbb05757c2b4', '46759aef-7aa8-46c5-8ac0-680c364ada23', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('6b89a30a-a486-456f-9f04-6db164f986f8', '4fa4dc68-46c0-4815-9c98-b6e12c63bc00', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('f836caf7-ef70-4eed-902b-eb99fdf3f97a', '4fa4dc68-46c0-4815-9c98-b6e12c63bc00', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('2217539b-0d90-438b-93cc-4d9193dd8796', '4fa4dc68-46c0-4815-9c98-b6e12c63bc00', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('07be5205-142d-45e2-8dc1-f3e822aeb058', '810d6556-23ed-4345-8f95-4356c6fe82d3', '12055968-78d3-4404-a05f-10e039217936', '11:00:00', '18:00:00', '2025-05-29 10:00:59.416309+00', '2025-05-29 10:00:59.416309+00'),
	('d915549d-c698-4639-99e7-9f6757064435', '890540ba-e31d-43b8-9d80-dcce462289b7', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '09:00:00', '18:00:00', '2025-05-29 10:07:11.46828+00', '2025-05-29 10:07:11.46828+00');


--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-28 14:11:31.279+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-28 14:11:31.279+00'),
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-28 14:11:31.279+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-28 14:11:31.279+00');


--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_porter_pool" ("id", "shift_id", "porter_id", "created_at", "updated_at") VALUES
	('0d10e71c-e9b9-4b00-97a7-50d7663711f2', '839b6adc-0b0d-4c92-bc14-7cd220308394', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-05-27 16:11:09.625755+00', '2025-05-27 16:11:09.625755+00'),
	('43fbe8c5-49bd-461b-abe4-fc763f7dda96', 'be379e15-5712-454f-9c1a-e429358828ec', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-28 13:48:11.001438+00', '2025-05-28 13:48:11.001438+00'),
	('d2fee56f-66eb-4e4f-b568-6722fa91dadf', 'be379e15-5712-454f-9c1a-e429358828ec', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '2025-05-28 13:48:11.079273+00', '2025-05-28 13:48:11.079273+00'),
	('969b1aa6-05d2-40cd-93bd-d9020d03c26c', 'be379e15-5712-454f-9c1a-e429358828ec', 'e55b1013-7e79-4e38-913e-c53de591f85c', '2025-05-28 13:48:11.146077+00', '2025-05-28 13:48:11.146077+00'),
	('7545fa7c-5b68-4457-9e26-f4223aab0bb9', 'be379e15-5712-454f-9c1a-e429358828ec', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-28 13:48:11.213451+00', '2025-05-28 13:48:11.213451+00'),
	('de015f32-71a4-4408-904a-ca842fd4c22a', '7e282dd3-0471-4202-9fe5-486a64309d1a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-28 13:55:53.915991+00', '2025-05-28 13:55:53.915991+00'),
	('404cd329-88a9-4d35-a167-f1e940ea61d2', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '2e74429e-2aab-4bed-a979-6ccbdef74596', '2025-05-28 14:08:05.164115+00', '2025-05-28 14:08:05.164115+00'),
	('83474009-733d-4a0f-ba0d-cea3faca319a', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-28 14:08:05.389702+00', '2025-05-28 14:08:05.389702+00'),
	('fc2e2055-d5a8-41ab-952e-0449f7269e79', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-28 14:08:05.434526+00', '2025-05-28 14:08:05.434526+00'),
	('d5d69008-1f9d-4691-ad9a-f7f4572560c3', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-05-28 14:08:05.482626+00', '2025-05-28 14:08:05.482626+00'),
	('b69a1084-60f9-420c-9b05-3921bb577ed5', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '2025-05-28 14:08:05.522336+00', '2025-05-28 14:08:05.522336+00'),
	('25850535-3e94-4067-8b34-47b1673ccffb', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '2025-05-28 14:08:05.568844+00', '2025-05-28 14:08:05.568844+00'),
	('5d89ecf1-cce9-4299-bd27-77e8ef915798', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '2025-05-28 14:08:05.613655+00', '2025-05-28 14:08:05.613655+00'),
	('6e942062-2cf6-44f3-93a5-ebbd68d7b45e', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '12055968-78d3-4404-a05f-10e039217936', '2025-05-28 14:08:05.663395+00', '2025-05-28 14:08:05.663395+00'),
	('f40dbecb-1ffb-4468-807b-c3883b8f94c8', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '8b3b3e97-ea54-4c40-884b-04d3d24dbe23', '2025-05-28 14:08:05.702999+00', '2025-05-28 14:08:05.702999+00'),
	('fa1213ba-2ba2-4678-8fde-5d6a0197d005', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'e55b1013-7e79-4e38-913e-c53de591f85c', '2025-05-28 14:08:05.751367+00', '2025-05-28 14:08:05.751367+00'),
	('fbb7b60c-191b-48d3-b41c-10a7cb19bee1', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '69766d05-49d7-4e7c-8734-e3dc8949bf91', '2025-05-28 14:08:05.815937+00', '2025-05-28 14:08:05.815937+00'),
	('959b4880-66e8-48c8-8abd-0ef4237dc6d7', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-28 14:08:05.869266+00', '2025-05-28 14:08:05.869266+00'),
	('87c310d0-921e-45e6-ad10-d1113a6b40ec', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-28 14:08:05.91762+00', '2025-05-28 14:08:05.91762+00'),
	('4f580b20-f0b7-4aaa-a272-d296bf90b304', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-28 14:08:05.999605+00', '2025-05-28 14:08:05.999605+00'),
	('e23d376a-4f90-4887-94c1-c5da28d3c8d7', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '2025-05-28 14:08:06.092398+00', '2025-05-28 14:08:06.092398+00'),
	('7fcd7b2d-1055-49e0-b2c2-7e4f8637b107', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '2025-05-28 14:08:06.141545+00', '2025-05-28 14:08:06.141545+00'),
	('dd9010a2-a228-4abf-b913-d7ef3e1f1e79', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '2025-05-28 14:08:06.196813+00', '2025-05-28 14:08:06.196813+00'),
	('dd592d82-1a3c-4014-ab4a-7f4315261bd6', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-28 15:30:52.88755+00', '2025-05-28 15:30:52.88755+00'),
	('affe80de-3da8-422a-8dbb-bc53a9a99d98', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-05-28 15:30:52.959437+00', '2025-05-28 15:30:52.959437+00'),
	('9fca45b6-fced-4ff3-9051-084543ca237b', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-28 15:30:53.034187+00', '2025-05-28 15:30:53.034187+00'),
	('9a9ed3be-19ce-4903-83c6-dbe8aee7154a', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '12055968-78d3-4404-a05f-10e039217936', '2025-05-29 10:00:38.774233+00', '2025-05-29 10:00:38.774233+00'),
	('3eeff123-e643-4215-a2a2-603c6239d3e2', '91f2c868-aa7c-484a-9c15-2a425fd744fe', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-29 10:00:38.8598+00', '2025-05-29 10:00:38.8598+00'),
	('1f09d456-3f7f-4fa8-a625-0ba687979bb7', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-29 10:00:38.926945+00', '2025-05-29 10:00:38.926945+00'),
	('e39da85b-4303-435f-aa2b-7282df273bac', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-29 10:00:39.006063+00', '2025-05-29 10:00:39.006063+00'),
	('c7935c03-d751-4ad1-a48a-0318078eae7b', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '394d8660-7946-4b31-87c9-b60f7e1bc294', '2025-05-29 10:00:39.068433+00', '2025-05-29 10:00:39.068433+00'),
	('6b89a013-6fe5-49f9-b1aa-a441e25f494c', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '2e74429e-2aab-4bed-a979-6ccbdef74596', '2025-05-29 10:00:39.128803+00', '2025-05-29 10:00:39.128803+00'),
	('4af9ff22-26be-4218-9bfb-77a05a9e0571', '91f2c868-aa7c-484a-9c15-2a425fd744fe', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '2025-05-29 10:00:39.198435+00', '2025-05-29 10:00:39.198435+00'),
	('91123ee9-a67a-4afe-a04e-b35baabb49f5', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-29 10:00:39.269607+00', '2025-05-29 10:00:39.269607+00');


--
-- Data for Name: shift_support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_assignments" ("id", "shift_id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('30077739-aeb6-491d-8151-4c4f8a4fa9c2', '839b6adc-0b0d-4c92-bc14-7cd220308394', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('d84b26ce-2438-4b47-a0c5-d50dc0cc0095', '839b6adc-0b0d-4c92-bc14-7cd220308394', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('73a02b7e-236a-49c9-b38c-0996035fc819', '839b6adc-0b0d-4c92-bc14-7cd220308394', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:00:00', '16:00:00', '#f4aa43', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('46204305-9b9b-42ae-b289-fd964d1bf96f', '7e282dd3-0471-4202-9fe5-486a64309d1a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('08c46020-035d-4e2b-83c9-0e2edc513833', '7e282dd3-0471-4202-9fe5-486a64309d1a', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('b6ae7610-73f2-4e56-a073-35b30850ba3a', '7e282dd3-0471-4202-9fe5-486a64309d1a', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:00:00', '16:00:00', '#f4aa43', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('fc23e89b-2699-4062-9ee6-69be5e4a0fee', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('23966e62-50e1-4e66-b83b-76ca1f58cf4f', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('524ce9d7-354c-4d3f-a36a-cb008967a0b1', 'acb1051e-087e-4ecf-90cc-f0f49ad61110', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:00:00', '16:00:00', '#f4aa43', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('2f442a11-6250-4538-988f-ea8ae60f22c2', 'c583b538-a3f2-43fe-bed3-5ec2a078c2db', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:05:41.346448+00', '2025-05-28 15:05:41.346448+00'),
	('766abcd5-7025-48c6-8a1b-160d85ac956e', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('00d6c4e8-93ac-49b0-87ac-22f9c6e526e4', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('fe6b7216-8d8b-45f8-b853-92922ec0d1f3', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('3896766e-92fc-459e-b05b-e31641da9004', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('5c75c20f-b9bf-4f69-b78b-a3f8aef3108a', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('24915467-c2f2-42db-9461-3d565f3587a6', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('30a49bcd-8f06-4236-b739-52f8ee639992', 'a0d0ab48-c0f8-49c2-a2e6-c526d8e8969a', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:30:11.819926+00', '2025-05-28 15:30:11.819926+00'),
	('f6afa557-aea4-44f3-b326-33c11be45b15', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('4a6566e3-a1e7-4431-81a8-a619cea9a5b9', '45f5eef8-e933-4853-bfe5-a4916746cdd2', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('cc09ecb9-d26d-4807-bf66-26c84f8cfbf6', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('cbee4468-bf62-42a2-8efe-fee4039a3c44', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('bbc51fc8-270b-489c-9739-357cc085d12f', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('71b7c781-3d3d-4f8d-bd73-285d21053086', '45f5eef8-e933-4853-bfe5-a4916746cdd2', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('136c72b1-f75d-4696-ab37-7450398cf19e', '45f5eef8-e933-4853-bfe5-a4916746cdd2', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('8c7f23f6-7d56-4cec-8936-e93d75791f1e', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('c43bf3c4-e9ad-427b-bcf3-6823c2719b17', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('f12d6174-5977-47eb-889b-493b52f17e23', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('a4012a93-3d2e-48d3-87c9-6cf1fbd4e52d', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('86614a00-3624-4e55-9608-37b05938bce7', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('b83a71b7-f7a4-4264-ad65-1969014ea906', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('58fa0ed4-ded0-4733-9a6c-ce9a950974d9', '4a5135f2-8d02-440d-8aa5-6a1c294ba43b', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('04dbebc9-5bef-40d8-975c-277ee048e31f', '58eb2384-c37d-423f-a568-cb98b757a16d', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('7566c06e-dab0-4b27-b44b-c73f88c83e5f', '58eb2384-c37d-423f-a568-cb98b757a16d', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('764d84b6-d2b6-48f7-9cfd-2d66d9438a20', '58eb2384-c37d-423f-a568-cb98b757a16d', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('46efb037-fcda-4c0d-8da5-3457d79bf428', '58eb2384-c37d-423f-a568-cb98b757a16d', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('ca67b1d6-aac0-44a4-a91e-8973664e04eb', '58eb2384-c37d-423f-a568-cb98b757a16d', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('32cce656-62cf-44ed-87d0-c18c5d034caf', '58eb2384-c37d-423f-a568-cb98b757a16d', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('5769bdea-06f1-49f5-8059-2e731f9e96f7', '58eb2384-c37d-423f-a568-cb98b757a16d', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:27:38.007138+00'),
	('88fd09aa-cca1-4add-a7de-2509162ab79f', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('831abe60-2731-4c94-8c8e-e13256378b86', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('5096ffe5-5c64-4d07-92a4-49ebd89f5fb3', '91f2c868-aa7c-484a-9c15-2a425fd744fe', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('6d637ba0-8de4-45a0-8686-ec6456e7fae8', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('cc840978-5f68-4008-9dfb-7af1ad91b47e', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('59033d45-7d48-4c82-aefc-26a17f77b7df', '91f2c868-aa7c-484a-9c15-2a425fd744fe', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('1c410148-1bb6-4fcf-8470-e141a92f7334', 'be379e15-5712-454f-9c1a-e429358828ec', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('70700b53-d159-4445-9f0a-5dd2deb26362', 'be379e15-5712-454f-9c1a-e429358828ec', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('46374378-33c8-474f-9155-9a4363e5a5f0', 'be379e15-5712-454f-9c1a-e429358828ec', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:00:00', '16:00:00', '#f4aa43', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('f1fa7d52-1d08-4f62-8f4b-1a91c32460c7', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('6118fbad-6a08-4959-857e-43c7fefa1e25', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('e7d095fe-3907-4e33-990d-6023e211b583', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:00:00', '16:00:00', '#f4aa43', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('fc1bd260-9e62-4e02-a8ba-32de02264fb9', 'e2ad7a21-f0b9-4a1b-84c0-ad11d2762c6d', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:04:34.918105+00', '2025-05-28 15:04:34.918105+00'),
	('1c0549cc-c526-4a21-8cfb-ecc870b4a285', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('ccdf91f9-0f7c-4083-b235-9063b2b783fa', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('155619b3-c05d-4e96-8ba6-c36bdf08661d', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('d847f5f2-9ce9-46ea-82e2-b434f7422f8e', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('aa3df9c7-e857-4242-98db-9498397a0c9f', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('693aed05-ba8b-4a8b-8d83-fd4978901f15', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('649cdb3f-52ab-4b85-8ef4-20dd7147733a', 'dcf08f05-08b7-467e-9169-c4f94747e5d6', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:23:38.345653+00', '2025-05-28 15:23:38.345653+00'),
	('be7a7cee-ef36-4912-bb7d-5a62c963d40b', '619f7fb8-02da-4e00-bcfc-c545603952fc', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('6e75ae70-46c9-4341-b168-d2d4eaab1275', '619f7fb8-02da-4e00-bcfc-c545603952fc', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('57a18c95-e708-4586-87f6-e9f8af1703d4', '619f7fb8-02da-4e00-bcfc-c545603952fc', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('7969ed0c-cf57-453a-a265-8d4c0766eda3', '619f7fb8-02da-4e00-bcfc-c545603952fc', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('feaafd12-8b8d-41ab-a528-f8a4f8d909b7', '619f7fb8-02da-4e00-bcfc-c545603952fc', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('ef9009f8-2309-4d78-9ccd-4704793219a2', '619f7fb8-02da-4e00-bcfc-c545603952fc', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('60a54f63-eb5c-4a89-85ad-ae79c095ae91', '619f7fb8-02da-4e00-bcfc-c545603952fc', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:34:50.253646+00', '2025-05-28 15:34:50.253646+00'),
	('0d7b0de4-0fc6-4ad7-b4d1-e35adcd59194', 'f68f03e9-119d-4d29-9af8-87f751147b52', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('66364c62-3ebf-4bcf-a65c-7e3f35a137ed', 'f68f03e9-119d-4d29-9af8-87f751147b52', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('5fe5d72d-8370-4020-9114-8fb12262515d', 'f68f03e9-119d-4d29-9af8-87f751147b52', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('3452f48f-7a60-416e-a0a1-c532bfd0abea', 'f68f03e9-119d-4d29-9af8-87f751147b52', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('b25176b8-a2da-4deb-86d3-87798925141e', 'f68f03e9-119d-4d29-9af8-87f751147b52', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('1a46cd1e-5992-4292-9e2e-a5a40784b487', 'f68f03e9-119d-4d29-9af8-87f751147b52', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('a03fcca7-656b-46dc-a253-95bf48c699b4', 'f68f03e9-119d-4d29-9af8-87f751147b52', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('c41307e0-ac9a-42d9-a571-781afcd2a483', '13e648a2-4857-4de4-903b-009644b0d6bc', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('d81e9d20-819b-40a0-a077-6a4ae1322360', '13e648a2-4857-4de4-903b-009644b0d6bc', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('8ac08c36-dae1-4569-ab71-f256af350dc4', '13e648a2-4857-4de4-903b-009644b0d6bc', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('20c219ce-a416-4dd3-ac91-94e8839eea18', '13e648a2-4857-4de4-903b-009644b0d6bc', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('340c8bb1-ed8a-4d07-ade4-a5d76d1a2e9f', '13e648a2-4857-4de4-903b-009644b0d6bc', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('5d611199-41d8-4b6b-b660-523f31a60368', '13e648a2-4857-4de4-903b-009644b0d6bc', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('e4d440cc-50d9-4268-a401-0b1015e9605c', '13e648a2-4857-4de4-903b-009644b0d6bc', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 06:53:53.531786+00', '2025-05-29 08:25:32.579474+00'),
	('13061bba-eeb9-4c87-bf9f-51120bcf979d', '206089d8-6208-4abf-a126-3d1fb00b3cae', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('684691c2-25ba-4906-9491-000be5a884d4', '206089d8-6208-4abf-a126-3d1fb00b3cae', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('393f8de6-a840-4ee7-8667-161050adc9f6', '206089d8-6208-4abf-a126-3d1fb00b3cae', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('2c3e5c4e-a773-42bc-bd35-46ea8407dae2', '206089d8-6208-4abf-a126-3d1fb00b3cae', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('df4e6345-56c8-4670-9006-bd7741c29035', '206089d8-6208-4abf-a126-3d1fb00b3cae', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('57b5507b-58a2-422c-b1e1-8c277ad1496a', '206089d8-6208-4abf-a126-3d1fb00b3cae', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('c5798f76-3559-492a-aa6d-3f09abfd3d15', '206089d8-6208-4abf-a126-3d1fb00b3cae', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('38743b9e-bb17-433c-8f1f-9e7a795c11d8', '91f2c868-aa7c-484a-9c15-2a425fd744fe', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 11:21:36.294266+00', '2025-05-29 11:21:36.294266+00');


--
-- Data for Name: shift_support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_porter_assignments" ("id", "shift_support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('c3bf91d1-d215-4936-8300-d6e23a5f93e5', '30077739-aeb6-491d-8151-4c4f8a4fa9c2', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('6ace8363-dc9f-463a-9d76-6de7f1f138c9', '30077739-aeb6-491d-8151-4c4f8a4fa9c2', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('5d069a38-997b-4e6d-ac50-f441668da61e', 'd84b26ce-2438-4b47-a0c5-d50dc0cc0095', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-27 16:11:03.414036+00', '2025-05-27 16:11:03.414036+00'),
	('369533b6-a86e-4b07-a875-4655fe073543', '1c410148-1bb6-4fcf-8470-e141a92f7334', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('7883cd73-5f47-485c-b615-098f6e0401bf', '1c410148-1bb6-4fcf-8470-e141a92f7334', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('24f3c3cf-6bc0-4e39-af65-b6c33841c144', '70700b53-d159-4445-9f0a-5dd2deb26362', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('54b564c2-5ea6-49ea-80f3-1b665e429587', '46204305-9b9b-42ae-b289-fd964d1bf96f', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('feeede04-bf12-49a6-8908-fb50bb721ec8', '46204305-9b9b-42ae-b289-fd964d1bf96f', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('3819efba-57e9-455d-929c-29a97b790393', '08c46020-035d-4e2b-83c9-0e2edc513833', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-28 13:50:49.996722+00', '2025-05-28 13:50:49.996722+00'),
	('6cccb04d-6b23-4e98-a72a-f2306272fd18', 'f1fa7d52-1d08-4f62-8f4b-1a91c32460c7', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('0f875f51-7b03-4505-a3b9-ffb108c02def', 'f1fa7d52-1d08-4f62-8f4b-1a91c32460c7', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('def43af2-41fe-4b40-9809-6a343a42d7b4', '6118fbad-6a08-4959-857e-43c7fefa1e25', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-28 14:07:53.648455+00', '2025-05-28 14:07:53.648455+00'),
	('5862c67b-74cd-4722-af1a-f7e664170ca5', 'fc23e89b-2699-4062-9ee6-69be5e4a0fee', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('4a96c76f-6f03-4195-b573-6c9aaf2fc285', 'fc23e89b-2699-4062-9ee6-69be5e4a0fee', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('2cbda22c-d0ab-4a9a-8f99-8036a829fd56', '23966e62-50e1-4e66-b83b-76ca1f58cf4f', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-28 14:14:11.170075+00', '2025-05-28 14:14:11.170075+00'),
	('670803b3-0c94-4b66-9eec-460d55bd6ae7', 'f6afa557-aea4-44f3-b326-33c11be45b15', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('ae0c2ea4-0125-4d12-8f27-94a2de77cad4', 'f6afa557-aea4-44f3-b326-33c11be45b15', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('b799881b-5702-4882-b3a1-68f5f3135a13', 'bbc51fc8-270b-489c-9739-357cc085d12f', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('bfea9072-45b1-40a7-8339-b9d293c16e5e', 'bbc51fc8-270b-489c-9739-357cc085d12f', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('6664616e-bde8-4256-82e2-dffe01a8395c', '71b7c781-3d3d-4f8d-bd73-285d21053086', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-28 15:50:27.909307+00', '2025-05-28 15:50:27.909307+00'),
	('f034946e-a03e-4b87-afd0-30f57b54be91', '0d7b0de4-0fc6-4ad7-b4d1-e35adcd59194', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('f41d9d9a-6280-4902-aca6-b863f8699c97', '0d7b0de4-0fc6-4ad7-b4d1-e35adcd59194', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('a4e7550a-46b8-49ea-9b75-1be9d81c81ec', 'b25176b8-a2da-4deb-86d3-87798925141e', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('9e0400c7-16ec-4a59-89f7-256193c7822f', 'b25176b8-a2da-4deb-86d3-87798925141e', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('894e6939-833f-4fae-98c1-d9f562b3f785', '1a46cd1e-5992-4292-9e2e-a5a40784b487', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 06:21:08.918092+00', '2025-05-29 06:21:08.918092+00'),
	('77068563-5552-448c-9a42-543e2b7728c2', '8c7f23f6-7d56-4cec-8936-e93d75791f1e', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('d42d9b60-f365-4e9b-84df-19f86cbaf1c8', '8c7f23f6-7d56-4cec-8936-e93d75791f1e', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('28bf40cb-05a3-46ca-a0df-774e88a8cec7', '86614a00-3624-4e55-9608-37b05938bce7', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('7cb619fc-edb7-49dc-8d6b-43f2dbb9e134', '86614a00-3624-4e55-9608-37b05938bce7', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('1febecb2-8b70-4ecd-aa73-ba09f3718215', 'b83a71b7-f7a4-4264-ad65-1969014ea906', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 06:40:27.262833+00', '2025-05-29 06:40:27.262833+00'),
	('c0bd8b5f-fa07-4c97-9a4a-881f1195cf9f', 'c41307e0-ac9a-42d9-a571-781afcd2a483', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('b2744e46-06cc-4f2f-a317-04cbd93335ed', 'c41307e0-ac9a-42d9-a571-781afcd2a483', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('bbd5204d-3dfb-433d-a8a8-51456cc44487', '340c8bb1-ed8a-4d07-ade4-a5d76d1a2e9f', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('5fca4a2a-4e1a-417c-b113-2e756c1a01b5', '340c8bb1-ed8a-4d07-ade4-a5d76d1a2e9f', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 06:53:53.531786+00'),
	('93776abc-18ef-402a-969a-aa6dd78ac112', 'e4d440cc-50d9-4268-a401-0b1015e9605c', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 06:53:53.531786+00', '2025-05-29 08:25:32.634982+00'),
	('147a1aae-69e4-41a6-8126-a5648f8ceb05', 'e4d440cc-50d9-4268-a401-0b1015e9605c', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '09:01:00', '11:01:00', '2025-05-29 07:01:17.140769+00', '2025-05-29 08:25:32.703966+00'),
	('a7f948f6-454f-4ce2-b647-f25234c7dab4', 'e4d440cc-50d9-4268-a401-0b1015e9605c', '786d6d23-69b9-433e-92ed-938806cb10a8', '14:25:00', '15:25:00', '2025-05-29 08:25:32.750812+00', '2025-05-29 08:25:32.750812+00'),
	('4cda74ff-f151-4301-8381-86b37af6c2d7', '04dbebc9-5bef-40d8-975c-277ee048e31f', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('e89053bb-f653-4012-9d0f-9dda5a168275', '04dbebc9-5bef-40d8-975c-277ee048e31f', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('0c676846-3ef7-40d2-b5d1-a8d6fecd6360', '46efb037-fcda-4c0d-8da5-3457d79bf428', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('01c63713-f819-48e2-83f5-011de297985a', '46efb037-fcda-4c0d-8da5-3457d79bf428', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('cf9eda63-fb57-4c22-8c88-8ec57f0fd414', 'ca67b1d6-aac0-44a4-a91e-8973664e04eb', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 08:26:34.45197+00', '2025-05-29 08:26:34.45197+00'),
	('ef0bb144-fce2-42dd-94d3-a45ed318b017', '5769bdea-06f1-49f5-8059-2e731f9e96f7', '56d5a952-a958-41c5-aa28-bd42e06720c8', '13:27:00', '14:27:00', '2025-05-29 08:27:38.059406+00', '2025-05-29 08:27:38.059406+00'),
	('c82cc0c3-9f63-4db3-885f-8dd22b582a5e', 'df4e6345-56c8-4670-9006-bd7741c29035', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('873c3bc2-8c48-41da-887f-160362751715', 'df4e6345-56c8-4670-9006-bd7741c29035', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('275de1f5-7826-4128-b157-93f1cbf58375', '57b5507b-58a2-422c-b1e1-8c277ad1496a', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('d32a78fc-55bc-4953-9702-5aecb6312b2d', '57b5507b-58a2-422c-b1e1-8c277ad1496a', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('e0086bde-9238-4637-a5cc-d0a0af68012e', 'c5798f76-3559-492a-aa6d-3f09abfd3d15', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('a5936fda-e8d0-4ba6-b86c-970c800a3d49', 'c5798f76-3559-492a-aa6d-3f09abfd3d15', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 09:11:27.702387+00', '2025-05-29 09:11:27.702387+00'),
	('4130735e-b355-485a-aabd-dd57cfe78b8e', '6d637ba0-8de4-45a0-8686-ec6456e7fae8', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('d342c49b-e764-4b3c-809e-4003efad62e4', '6d637ba0-8de4-45a0-8686-ec6456e7fae8', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('ba91b549-6741-4863-80c6-cce3db797730', 'cc840978-5f68-4008-9dfb-7af1ad91b47e', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('1fe101bd-4b8e-4b9a-992e-d5fd08709efa', 'cc840978-5f68-4008-9dfb-7af1ad91b47e', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('c7f730a5-bf1a-4c78-a402-2666c933adae', '59033d45-7d48-4c82-aefc-26a17f77b7df', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00'),
	('769db789-4905-49ee-b14d-ef3c9c2344b5', '59033d45-7d48-4c82-aefc-26a17f77b7df', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 09:59:18.179352+00', '2025-05-29 09:59:18.179352+00');


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

INSERT INTO "public"."task_items" ("id", "task_type_id", "name", "description", "created_at", "updated_at") VALUES
	('e6068d5d-4bc5-4358-8bae-ed23759dc733', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen F Size', NULL, '2025-05-22 11:25:09.159861+00', '2025-05-22 11:25:09.159861+00'),
	('8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed (Complete)', NULL, '2025-05-22 12:00:44.450407+00', '2025-05-22 12:00:44.450407+00'),
	('a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed Frame', NULL, '2025-05-22 12:00:52.076144+00', '2025-05-22 12:00:52.076144+00'),
	('93150478-e3b7-4315-bfb2-8f44a78b2f77', 'b864ed57-5547-404e-9459-1641a030974e', 'Mattress', NULL, '2025-05-24 15:17:23.893487+00', '2025-05-24 15:17:23.893487+00'),
	('532b14f0-042a-4ddf-bc7d-cb95ff298132', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Incubator', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:17:40.681145+00'),
	('5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen E Size', NULL, '2025-05-24 15:18:10.625096+00', '2025-05-24 15:18:10.625096+00'),
	('f18bf0ce-835e-4d9d-92d0-119222a56f5e', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen D Size', NULL, '2025-05-24 15:18:21.251002+00', '2025-05-24 15:18:21.251002+00'),
	('377506db-7bf7-44e8-bc8f-c7c316914579', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Entenox E Size', NULL, '2025-05-24 15:18:39.13243+00', '2025-05-24 15:18:39.13243+00'),
	('14446938-25cd-4655-ad84-dbb7db871f28', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Bed', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:50.766252+00'),
	('68e8e006-79dc-4d5f-aed0-20755d53403b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Wheelchair', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:56.015534+00'),
	('5c269ddd-7abd-4d10-a0b3-d93fccb4f6de', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Trolly', NULL, '2025-05-24 15:19:02.302787+00', '2025-05-24 15:19:02.302787+00'),
	('dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Blood Sample', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:19:31.625374+00'),
	('934256c2-fbe5-480b-a0ac-897d9d5b9358', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Urine Sample', NULL, '2025-05-24 15:19:41.366895+00', '2025-05-24 15:19:41.366895+00'),
	('5c0c9e25-ae34-4872-8696-4c4ce6e76112', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Multiple Samples', NULL, '2025-05-24 15:19:53.083235+00', '2025-05-24 15:19:53.083235+00'),
	('e5e84800-eb11-4889-bb97-39ea75ef5190', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Blood', NULL, '2025-05-24 15:23:49.29882+00', '2025-05-24 15:23:49.29882+00'),
	('ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Albumen', NULL, '2025-05-24 15:23:58.062632+00', '2025-05-24 15:23:58.062632+00'),
	('b55609c2-9be4-4851-ad2c-dfc199795298', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Platelets', NULL, '2025-05-24 15:24:05.948941+00', '2025-05-24 15:24:05.948941+00'),
	('b8fed973-ab36-4d31-801a-7ebbde95413a', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed (Complete)', NULL, '2025-05-24 15:27:01.862194+00', '2025-05-24 15:27:01.862194+00'),
	('81e0d17c-740a-4a00-9727-81d222f96234', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed Frame', NULL, '2025-05-24 15:27:10.580403+00', '2025-05-24 15:27:10.580403+00'),
	('deab62e1-ae79-4f77-ab65-0a04c1f040a1', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Mattress', NULL, '2025-05-24 15:27:17.680461+00', '2025-05-24 15:27:17.680461+00'),
	('1933a5d4-e02d-4301-b580-a0fdbdbfb21d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Walk', NULL, '2025-05-25 09:51:59.07475+00', '2025-05-25 09:51:59.07475+00'),
	('be835d6f-62c6-48bf-ae5f-5257e097349b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Rose Cottage', NULL, '2025-05-27 15:50:47.505753+00', '2025-05-27 15:50:47.505753+00');


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('644691e6-62a5-434e-ae42-56baad5fdfee', '839b6adc-0b0d-4c92-bc14-7cd220308394', '532b14f0-042a-4ddf-bc7d-cb95ff298132', NULL, 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', NULL, 'completed', '2025-05-27 16:11:21.685585+00', '2025-05-27 16:11:21.685585+00', '2025-05-27T17:11:00', '2025-05-27T17:12:00', '2025-05-27T17:31:00'),
	('eab0e491-0386-40e6-a28e-a214592f4718', 'be379e15-5712-454f-9c1a-e429358828ec', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-05-28 13:47:26.082777+00', '2025-05-28 13:47:26.082777+00', '2025-05-28T14:47:00', '2025-05-28T14:48:00', '2025-05-28T15:07:00'),
	('d8937dae-9b65-4c18-b2b2-aa875c3d99b8', 'be379e15-5712-454f-9c1a-e429358828ec', '81e0d17c-740a-4a00-9727-81d222f96234', NULL, 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-28 13:47:54.071702+00', '2025-05-28 13:47:54.071702+00', '2025-05-28T14:47:00', '2025-05-28T14:48:00', '2025-05-28T15:07:00'),
	('17de8743-2e07-4cde-a483-ef0f73f27ba4', '6db8a6d8-eb81-4aa2-8015-7174d4a41aa1', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '969a27a7-f5e5-4c23-b018-128aa2000b97', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-28 14:13:22.581451+00', '2025-05-28 14:13:22.581451+00', '2025-05-28T15:13:00', '2025-05-28T15:14:00', '2025-05-28T15:33:00'),
	('9722e7b8-291b-49ff-919c-4f44905b650d', 'be379e15-5712-454f-9c1a-e429358828ec', '5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-28 13:48:28.11982+00', '2025-05-29 08:52:00.278251+00', '2025-05-28T14:48:00', '2025-05-28T14:49:00', '2025-05-28T15:08:00');


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
	('b081b8d8-27e2-4538-9d83-b1512f9f77ff', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', true, false, '2025-05-24 15:25:45.227716+00'),
	('33dc4387-f8a6-4e35-ae5d-303c806a7a71', '5c0c9e25-ae34-4872-8696-4c4ce6e76112', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', true, false, '2025-05-24 15:26:02.940817+00'),
	('1c92bb0d-1130-4e11-bf56-b9bfc1f6a49d', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', true, false, '2025-05-27 16:10:54.167911+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ceaa8539-8fd6-4954-8c00-2f8aea4bb3a6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '9056ee14-242b-4208-a87d-fc59d24d442c', false, true, '2025-05-24 12:33:59.810318+00'),
	('bfda15f6-809b-436f-abd2-d2c16dd7663c', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '81c30d93-8712-405c-ac5e-509d48fd9af9', true, false, '2025-05-24 15:22:58.114521+00'),
	('100f3cf6-3d37-4e48-90f3-c01b7874856b', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', true, false, '2025-05-24 15:23:36.64394+00');


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
