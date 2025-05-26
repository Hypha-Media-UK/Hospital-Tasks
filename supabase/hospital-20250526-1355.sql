

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


CREATE OR REPLACE FUNCTION "public"."copy_default_assignments_to_shift"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Copy default area cover assignments for this shift type
  INSERT INTO shift_area_cover_assignments (
    shift_id, department_id, start_time, end_time, color
  )
  SELECT 
    NEW.id, 
    department_id, 
    start_time, 
    end_time, 
    color
  FROM default_area_cover_assignments
  WHERE shift_type = NEW.shift_type;
  
  -- For each area cover assignment, copy any porter assignments
  INSERT INTO shift_area_cover_porter_assignments (
    shift_area_cover_assignment_id, porter_id, start_time, end_time
  )
  SELECT 
    saca.id,
    dapa.porter_id,
    dapa.start_time,
    dapa.end_time
  FROM default_area_cover_porter_assignments dapa
  JOIN default_area_cover_assignments daca ON dapa.default_area_cover_assignment_id = daca.id
  JOIN shift_area_cover_assignments saca ON 
    saca.department_id = daca.department_id AND
    saca.shift_id = NEW.id;
  
  -- Copy default service cover assignments for this shift type
  INSERT INTO shift_support_service_assignments (
    shift_id, service_id, start_time, end_time, color
  )
  SELECT 
    NEW.id, 
    service_id, 
    start_time, 
    end_time, 
    color
  FROM default_service_cover_assignments
  WHERE shift_type = NEW.shift_type;
  
  -- For each service cover assignment, copy any porter assignments
  INSERT INTO shift_support_service_porter_assignments (
    shift_support_service_assignment_id, porter_id, start_time, end_time
  )
  SELECT 
    sssa.id,
    dspa.porter_id,
    dspa.start_time,
    dspa.end_time
  FROM default_service_cover_porter_assignments dspa
  JOIN default_service_cover_assignments dsca ON dspa.default_service_cover_assignment_id = dsca.id
  JOIN shift_support_service_assignments sssa ON 
    sssa.service_id = dsca.service_id AND
    sssa.shift_id = NEW.id;
    
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."copy_default_assignments_to_shift"() OWNER TO "postgres";


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
  v_porter_id UUID;
  v_start_time TIME;
  v_end_time TIME;
  r_area_assignment RECORD;
  r_service_assignment RECORD;
  r_area_porter RECORD;
  r_service_porter RECORD;
BEGIN
  -- Copy area cover assignments from defaults to shift
  FOR r_area_assignment IN 
    SELECT * FROM default_area_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Insert into shift_area_cover_assignments
    INSERT INTO shift_area_cover_assignments (
      shift_id, department_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_area_assignment.department_id, r_area_assignment.start_time, 
      r_area_assignment.end_time, r_area_assignment.color
    ) RETURNING id INTO v_area_cover_assignment_id;
    
    -- Store the default ID for later
    v_default_area_cover_id := r_area_assignment.id;
    
    -- Copy porter assignments for this area cover
    FOR r_area_porter IN 
      SELECT * FROM default_area_cover_porter_assignments 
      WHERE default_area_cover_assignment_id = v_default_area_cover_id
    LOOP
      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_area_cover_assignment_id, r_area_porter.porter_id, 
        r_area_porter.start_time, r_area_porter.end_time
      );
    END LOOP;
  END LOOP;
  
  -- Copy service cover assignments from defaults to shift
  FOR r_service_assignment IN 
    SELECT * FROM default_service_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Insert into shift_support_service_assignments
    INSERT INTO shift_support_service_assignments (
      shift_id, service_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_service_assignment.service_id, r_service_assignment.start_time, 
      r_service_assignment.end_time, r_service_assignment.color
    ) RETURNING id INTO v_service_cover_assignment_id;
    
    -- Store the default ID for later
    v_default_service_cover_id := r_service_assignment.id;
    
    -- Copy porter assignments for this service cover
    FOR r_service_porter IN 
      SELECT * FROM default_service_cover_porter_assignments 
      WHERE default_service_cover_assignment_id = v_default_service_cover_id
    LOOP
      INSERT INTO shift_support_service_porter_assignments (
        shift_support_service_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_service_cover_assignment_id, r_service_porter.porter_id, 
        r_service_porter.start_time, r_service_porter.end_time
      );
    END LOOP;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) OWNER TO "postgres";


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
    "updated_at" timestamp with time zone DEFAULT "now"()
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
    "updated_at" timestamp with time zone DEFAULT "now"()
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
    "department_id" "uuid"
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



CREATE INDEX "departments_building_id_idx" ON "public"."departments" USING "btree" ("building_id");



CREATE INDEX "idx_default_area_cover_porter_assignment" ON "public"."default_area_cover_porter_assignments" USING "btree" ("default_area_cover_assignment_id");



CREATE INDEX "idx_default_area_cover_shift_type" ON "public"."default_area_cover_assignments" USING "btree" ("shift_type");



CREATE INDEX "idx_default_service_cover_porter_assignment" ON "public"."default_service_cover_porter_assignments" USING "btree" ("default_service_cover_assignment_id");



CREATE INDEX "idx_default_service_cover_shift_type" ON "public"."default_service_cover_assignments" USING "btree" ("shift_type");



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



CREATE OR REPLACE TRIGGER "copy_defaults_on_shift_creation" AFTER INSERT ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."copy_defaults_on_shift_creation"();



CREATE OR REPLACE TRIGGER "copy_defaults_to_new_shift" AFTER INSERT ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."copy_defaults_on_shift_creation"();



CREATE OR REPLACE TRIGGER "trigger_copy_default_assignments" AFTER INSERT ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."copy_default_assignments_to_shift"();



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

























































































































































GRANT ALL ON FUNCTION "public"."copy_default_assignments_to_shift"() TO "anon";
GRANT ALL ON FUNCTION "public"."copy_default_assignments_to_shift"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."copy_default_assignments_to_shift"() TO "service_role";



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
	('22639f07-209d-41e6-b3e3-f569b6c4db96', 'GMT', '24h', '2025-05-24 12:03:15.409004+00', '2025-05-24 12:03:15.198+00');


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."buildings" ("id", "name", "address", "created_at", "updated_at") VALUES
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-05-22 10:41:06.907057+00'),
	('d4d0bf79-eb71-477e-9d06-03159039e425', 'New Fountain House', NULL, '2025-05-24 12:20:27.560098+00', '2025-05-24 12:20:27.560098+00'),
	('5e80f040-98ba-4969-9e69-99149664ecac', 'Stores', NULL, '2025-05-24 12:21:43.496202+00', '2025-05-24 12:21:43.496202+00'),
	('e85c40e7-6f29-4e22-9787-6ed289c36429', 'Charlesworth Building', NULL, '2025-05-24 12:20:54.129832+00', '2025-05-24 14:01:55.535889+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ladysmith Building', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-24 15:10:52.043497+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Werneth House', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-05-24 15:15:47.821777+00'),
	('69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Unit', NULL, '2025-05-24 15:31:30.919629+00', '2025-05-24 15:31:30.919629+00'),
	('23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Portland Building', NULL, '2025-05-24 15:33:42.930237+00', '2025-05-24 15:33:42.930237+00'),
	('e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal Unit', NULL, '2025-05-24 15:34:16.907485+00', '2025-05-24 15:34:16.907485+00'),
	('e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Bereavement Centre', NULL, '2025-05-24 15:12:37.764027+00', '2025-05-25 09:15:35.971868+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at") VALUES
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', false, '2025-05-22 10:41:18.749919+00', '2025-05-22 10:41:18.749919+00'),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-05-23 14:37:10.792334+00'),
	('2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'NICU', false, '2025-05-24 12:21:01.329031+00', '2025-05-24 12:21:01.329031+00'),
	('52c4ae93-8ede-45d9-b5ff-d5e87b4f20aa', '5e80f040-98ba-4969-9e69-99149664ecac', 'Gas Store', false, '2025-05-24 12:21:52.935222+00', '2025-05-24 12:21:52.935222+00'),
	('6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 27', false, '2025-05-24 15:04:56.615271+00', '2025-05-24 15:04:56.615271+00'),
	('fa9e4d42-8282-42f8-bfd4-87691e20c7ed', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Ward', false, '2025-05-24 15:05:14.044021+00', '2025-05-24 15:05:14.044021+00'),
	('9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 30 (HCU)', false, '2025-05-24 15:05:26.651408+00', '2025-05-24 15:05:26.651408+00'),
	('c24a3784-6a06-469f-a764-49621f2d88d3', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 31', false, '2025-05-24 15:05:37.494475+00', '2025-05-24 15:05:37.494475+00'),
	('8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'IAU', false, '2025-05-24 15:05:46.603744+00', '2025-05-24 15:05:46.603744+00'),
	('6dc82d06-d4d2-4824-9a83-d89b583b7554', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'SDEC', false, '2025-05-24 15:05:53.620867+00', '2025-05-24 15:05:53.620867+00'),
	('a8d3be01-4d46-41c1-b304-ab98610847e7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Vasular Studies', false, '2025-05-24 15:06:04.488647+00', '2025-05-24 15:06:10.489707+00'),
	('1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'A+E (ED)', false, '2025-05-24 15:06:24.428146+00', '2025-05-24 15:06:24.428146+00'),
	('f9d3bbce-8644-4075-8b80-457777f6d16c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Ground Floor', false, '2025-05-24 15:06:39.563069+00', '2025-05-24 15:06:39.563069+00'),
	('8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Lower Ground Floor', false, '2025-05-24 15:06:52.499906+00', '2025-05-24 15:06:52.499906+00'),
	('42c2b3ab-f68d-429c-9675-3c79ff0ed222', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Ultrasound', false, '2025-05-24 15:07:04.431723+00', '2025-05-24 15:07:04.431723+00'),
	('35c73844-b511-423e-996c-5328ef21fedd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Clinics A-F', false, '2025-05-24 15:07:14.550747+00', '2025-05-24 15:07:14.550747+00'),
	('7295def1-1827-46dc-a443-a7aa7bf85b52', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Yellow Suite', false, '2025-05-24 15:07:27.863388+00', '2025-05-24 15:07:27.863388+00'),
	('f7c99832-60d1-42ee-8d35-0620a38f1e5d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Blue Suite', false, '2025-05-24 15:07:36.0704+00', '2025-05-24 15:07:36.0704+00'),
	('465893b5-6ab8-4776-bdbd-fd3c608ab966', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Swan Room', false, '2025-05-24 15:07:48.317926+00', '2025-05-24 15:07:48.317926+00'),
	('dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s Unit', false, '2025-05-24 15:08:15.838239+00', '2025-05-24 15:08:15.838239+00'),
	('ac2333d2-0b37-4924-a039-478caf702fbd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s O+A', false, '2025-05-24 15:08:31.112268+00', '2025-05-24 15:08:31.112268+00'),
	('7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Day Surgery', false, '2025-05-24 15:09:06.573728+00', '2025-05-24 15:09:06.573728+00'),
	('4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Endoscopy Unit', false, '2025-05-24 15:09:18.185641+00', '2025-05-24 15:09:18.185641+00'),
	('c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'POU', false, '2025-05-24 15:09:37.760662+00', '2025-05-24 15:09:37.760662+00'),
	('f7525622-cd84-4c8c-94bf-b0428008b9c3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Frailty', false, '2025-05-24 15:10:12.266212+00', '2025-05-24 15:10:12.266212+00'),
	('36e599c5-89b2-4d50-b7df-47d5d1959ca4', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Surgical Hub', false, '2025-05-24 15:10:26.062318+00', '2025-05-24 15:10:26.062318+00'),
	('19b02bca-1dc6-4d00-b04d-a7e141a04870', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Plaster Room', false, '2025-05-24 15:10:32.921441+00', '2025-05-24 15:10:32.921441+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 40', false, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:10:59.203581+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 41', false, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:11:06.887444+00'),
	('3aa17398-7823-45ae-b76c-9b30d8509ce1', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 42', false, '2025-05-24 15:11:16.394196+00', '2025-05-24 15:11:16.394196+00'),
	('76753b4b-ae1e-4477-a042-8deaab558e7b', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Discharge Lounge', false, '2025-05-24 15:11:40.525042+00', '2025-05-24 15:11:40.525042+00'),
	('1ae5c936-b74c-453e-a614-42b983416e40', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 43', false, '2025-05-24 15:11:49.971178+00', '2025-05-24 15:11:49.971178+00'),
	('0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 44', false, '2025-05-24 15:11:55.713923+00', '2025-05-24 15:11:55.713923+00'),
	('569e9211-d394-4e93-ba3e-34ad20d98af4', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 45', false, '2025-05-24 15:12:01.01766+00', '2025-05-24 15:12:01.01766+00'),
	('0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 46', false, '2025-05-24 15:12:07.981632+00', '2025-05-24 15:12:07.981632+00'),
	('99d8db21-2c14-4f8f-8e54-54fc81004997', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Rose Cottage', false, '2025-05-24 15:12:49.940045+00', '2025-05-24 15:12:49.940045+00'),
	('87a21a43-fe29-448f-9c08-b4d94226ad3f', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Infection Control', false, '2025-05-24 15:13:12.738948+00', '2025-05-24 15:13:12.738948+00'),
	('60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Switch', false, '2025-05-24 15:13:28.133871+00', '2025-05-24 15:13:28.133871+00'),
	('c06cd3c4-8993-4e7b-b198-a7fda4ede658', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Estates Management', false, '2025-05-24 15:13:37.481503+00', '2025-05-24 15:13:55.996814+00'),
	('a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'CDS (Acorn Birth Centre)', false, '2025-05-24 15:14:21.560252+00', '2025-05-24 15:14:40.302505+00'),
	('571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Womens Health', false, '2025-05-24 15:14:53.225063+00', '2025-05-24 15:14:53.225063+00'),
	('23199491-fe75-4c33-9cc8-1c86070cf0d1', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Triage', false, '2025-05-24 15:15:20.429518+00', '2025-05-24 15:15:20.429518+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Library', false, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:15:56.37151+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d488', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Lecture Theatre', true, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:16:06.796323+00'),
	('c0a07de6-b201-441b-a1fb-2b2ae9a95ac1', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Reception', false, '2025-05-24 15:16:21.942089+00', '2025-05-24 15:16:21.942089+00'),
	('bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Transfusion', false, '2025-05-24 15:20:33.127806+00', '2025-05-24 15:20:33.127806+00'),
	('9056ee14-242b-4208-a87d-fc59d24d442c', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Pathology Lab', false, '2025-05-24 12:20:41.049859+00', '2025-05-24 15:20:39.255686+00'),
	('969a27a7-f5e5-4c23-b018-128aa2000b97', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Bed Store', false, '2025-05-24 15:21:21.166917+00', '2025-05-24 15:21:21.166917+00'),
	('5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Mattress Store', false, '2025-05-24 15:21:31.144781+00', '2025-05-24 15:21:31.144781+00'),
	('9dae2f86-2058-4c9c-a428-76f5648553d3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'North Theatres', false, '2025-05-24 15:24:43.214387+00', '2025-05-24 15:24:43.214387+00'),
	('07e2b454-88ee-4d6a-9d75-a6ffa39bd241', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'South Theatres', false, '2025-05-24 15:24:51.854136+00', '2025-05-24 15:24:51.854136+00'),
	('5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'CT Scanner', false, '2025-05-24 15:25:11.218374+00', '2025-05-24 15:25:11.218374+00'),
	('d82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'MRI', false, '2025-05-24 15:25:16.973586+00', '2025-05-24 15:25:16.973586+00'),
	('df3d8d2a-dee5-4a21-a362-401236a2a1cb', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Pharmacy', false, '2025-05-24 15:30:28.871857+00', '2025-05-24 15:30:28.871857+00'),
	('943915e4-6818-4890-b395-a8272718eaf7', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford One', false, '2025-05-24 15:31:43.707094+00', '2025-05-24 15:31:43.707094+00'),
	('0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Two', false, '2025-05-24 15:31:53.020936+00', '2025-05-24 15:31:53.020936+00'),
	('1cac53b0-f370-4a13-95ca-f4cfd85dd197', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Ground', false, '2025-05-24 15:32:00.795352+00', '2025-05-24 15:32:00.795352+00'),
	('55f54692-d1ee-4047-bace-ff31744d2bc7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'FM Corridor', false, '2025-05-24 15:32:36.1272+00', '2025-05-24 15:32:36.1272+00'),
	('270df887-a13f-4004-a58d-9cec125b8da1', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Kitchens', false, '2025-05-24 15:32:43.567186+00', '2025-05-24 15:32:43.567186+00'),
	('06582332-0637-4d1a-b86e-876afe0bdc98', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Laundry', false, '2025-05-24 15:33:51.477397+00', '2025-05-24 15:33:51.477397+00'),
	('bf03ffcf-98d7-440e-adc1-5081e161c42d', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'I.T.', false, '2025-05-24 15:33:57.806509+00', '2025-05-24 15:33:57.806509+00'),
	('2368699a-6de0-45a9-ae25-dad26160cada', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Porters Lodge', false, '2025-05-24 15:34:07.683358+00', '2025-05-24 15:34:07.683358+00'),
	('ccb6bf8f-275c-4d24-8907-09b97cbe0eea', 'e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal', false, '2025-05-24 15:34:28.590837+00', '2025-05-24 15:34:28.590837+00');


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id") VALUES
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'Porter', 'Three', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-22 15:14:47.797324+00', NULL),
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'Martin', 'Smith', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-05-22 16:38:43.142566+00', NULL),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'Martin', 'Fearon', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-05-22 16:38:53.581199+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484'),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'Chris', 'Chrombie', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-05-22 16:39:03.319212+00', NULL),
	('a9d969e3-d449-4005-a679-f63be07c6872', 'Luke', 'Clements', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-05-22 16:39:16.282662+00', NULL),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'Porter', 'Four', 'porter', '2025-05-23 14:15:42.030594+00', '2025-05-23 14:15:42.030594+00', NULL),
	('2e74429e-2aab-4bed-a979-6ccbdef74596', 'Porter', 'Six', 'porter', '2025-05-24 15:27:50.974195+00', '2025-05-24 15:27:50.974195+00', NULL),
	('ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', 'Porter', 'Seven', 'porter', '2025-05-24 15:28:02.842334+00', '2025-05-24 15:28:02.842334+00', NULL),
	('78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', 'Porter', 'Eight', 'porter', '2025-05-24 15:28:08.999647+00', '2025-05-24 15:28:08.999647+00', NULL),
	('bf79faf6-fb3e-4780-841e-63a4a67a5b77', 'Porter', 'Nine', 'porter', '2025-05-24 15:28:15.192437+00', '2025-05-24 15:28:15.192437+00', NULL),
	('8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'Porter', 'Ten', 'porter', '2025-05-24 15:28:21.287841+00', '2025-05-24 15:28:21.287841+00', NULL),
	('7c20aec3-bf78-4ef9-b35e-429e41ac739b', 'Porter', 'Eleven', 'porter', '2025-05-24 15:28:35.013201+00', '2025-05-24 15:28:35.013201+00', NULL),
	('ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'Porter', 'Twelve', 'porter', '2025-05-24 15:28:41.635621+00', '2025-05-24 15:28:41.635621+00', NULL),
	('2524b1c5-45e1-4f15-bf3b-984354f22cdc', 'Porter', 'Thirteen', 'porter', '2025-05-24 15:28:50.433536+00', '2025-05-24 15:28:50.433536+00', NULL),
	('f304fa99-8e00-48d0-a616-d156b0f7484d', 'Porter', 'Fourteen', 'porter', '2025-05-24 15:29:00.080381+00', '2025-05-24 15:29:00.080381+00', NULL),
	('4fb21c6f-2f5b-4f6e-b727-239a3391092a', 'Porter', 'Fifteen', 'porter', '2025-05-24 15:29:10.541023+00', '2025-05-24 15:29:10.541023+00', NULL),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'Porter', 'Five', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-24 15:29:23.335292+00', NULL),
	('12055968-78d3-4404-a05f-10e039217936', 'Porter', 'One', 'porter', '2025-05-24 15:35:19.897285+00', '2025-05-24 15:35:19.897285+00', NULL),
	('8b3b3e97-ea54-4c40-884b-04d3d24dbe23', 'Porter', 'Sixteen', 'porter', '2025-05-24 15:46:43.723804+00', '2025-05-24 15:46:43.723804+00', NULL),
	('8eaa9194-b164-4cb4-a15c-956299ff28c5', 'Porter', 'Seventeen', 'porter', '2025-05-24 15:46:56.110419+00', '2025-05-24 15:46:56.110419+00', NULL),
	('e55b1013-7e79-4e38-913e-c53de591f85c', 'Porter', 'Eighteen', 'porter', '2025-05-24 15:47:03.70938+00', '2025-05-24 15:47:03.70938+00', NULL),
	('4e87f01b-5196-47c4-b424-4cfdbe7fb385', 'Porter', 'Nineteen', 'porter', '2025-05-24 15:47:12.658077+00', '2025-05-24 15:47:12.658077+00', NULL),
	('69766d05-49d7-4e7c-8734-e3dc8949bf91', 'Porter', 'Twenty', 'porter', '2025-05-24 15:47:22.720752+00', '2025-05-24 15:47:22.720752+00', NULL),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'Porter', 'Two', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-25 09:56:14.035659+00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a');


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
	('22b77327-905a-41ae-807d-b325c0bd676e', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 11:45:47.554456+00', '2025-05-26 12:02:25.836153+00'),
	('e955ff9b-72ea-4310-9e6b-03ab723ef063', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('2f844292-31ad-4887-8c26-c60ff0cc6487', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('cc8724da-4643-4434-89ea-08b8ab314e00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('4c1102f9-66a8-4f6a-a4f5-d7e70295f5e6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_night', '20:00:00', '08:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('e56d34fc-9318-4eba-bb4d-244d17a69a56', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'week_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('8c0e6b3f-50a6-4b30-bbfc-8ba073d55715', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00');


--
-- Data for Name: default_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_porter_assignments" ("id", "default_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('0139ee7f-9f91-4e6d-9194-1d038d41e155', 'e955ff9b-72ea-4310-9e6b-03ab723ef063', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00');


--
-- Data for Name: support_services; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_services" ("id", "name", "description", "is_active", "created_at", "updated_at") VALUES
	('30c5c045-a442-4ec8-b285-c7bc010f4d83', 'Laundry', 'Porter support for laundry services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ce940139-6ae7-49de-a62a-0d6ba9397928', 'Post', 'Internal mail and document delivery', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('0b5c7062-1285-4427-8387-b1b4e14eedc9', 'Pharmacy', 'Medication delivery service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'District Drivers', 'External transport services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('7cfa1ddf-61b0-489e-ad23-b924cf995419', 'Adhoc', 'Miscellaneous tasks requiring porter assistance', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('26c0891b-56c0-4346-8d53-de906aaa64c2', 'Medical Records', 'Patient records transport service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00');


--
-- Data for Name: default_service_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_assignments" ("id", "service_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('ba04ddd3-6b77-4bc8-b99a-7fef682d00e3', '0b5c7062-1285-4427-8387-b1b4e14eedc9', 'week_night', '20:00:00', '04:00:00', '#FBBC05', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('e36aba06-8605-41bf-b83f-cb2a783489ff', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 11:51:34.925616+00', '2025-05-26 12:10:13.916042+00'),
	('4737598a-6495-49cb-b849-9e282b6eae80', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'weekend_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('6336ef64-dd62-486b-b99b-e4325b7e097c', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('9f5f2b11-644f-489d-b807-8e3e87183658', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'week_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('be7efa06-7370-4006-8b27-bebc3a59b808', '7cfa1ddf-61b0-489e-ad23-b924cf995419', 'weekend_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('932d1201-641d-41f4-8353-f5b95977044b', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'weekend_day', '09:00:00', '17:00:00', '#EA4335', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('0c735c25-421d-4052-9f44-8afed7acbe6f', 'ce940139-6ae7-49de-a62a-0d6ba9397928', 'week_day', '08:00:00', '16:00:00', '#34A853', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00');


--
-- Data for Name: default_service_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_porter_assignments" ("id", "default_service_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('9e14cce6-bf66-4b4b-9cc6-da6fd35e829e', 'e36aba06-8605-41bf-b83f-cb2a783489ff', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-26 12:02:42.525758+00', '2025-05-26 12:02:42.525758+00'),
	('1be421f7-cfdc-4ee3-838f-1b71dffa9cfa', '4737598a-6495-49cb-b849-9e282b6eae80', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:58:00', '22:58:00', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('e5c9a78b-ed90-4add-94ed-60d9b4916e21', '0c735c25-421d-4052-9f44-8afed7acbe6f', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00'),
	('922896af-9090-4bfd-8a4e-d27a20e88c4c', 'e36aba06-8605-41bf-b83f-cb2a783489ff', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-26 12:10:13.916042+00', '2025-05-26 12:10:13.916042+00');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d490', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'week_day', '2025-05-23 06:24:46.89275+00', '2025-05-23 14:15:59.682+00', false, '2025-05-23 08:24:46.89275+00', '2025-05-25 12:42:22.502735+00'),
	('eca831e9-fa9f-4604-9526-0a6f70040f86', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-23 08:47:36.33+00', '2025-05-23 14:16:03.596+00', false, '2025-05-23 08:47:36.411612+00', '2025-05-25 12:42:22.502735+00'),
	('f9f8c607-d370-4ed8-94f0-dcee9f9be460', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-25 11:21:45.9+00', '2025-05-25 11:38:07.735+00', false, '2025-05-25 11:21:45.975115+00', '2025-05-25 12:42:22.502735+00'),
	('cc6d807e-7cb1-4e6f-8084-7068760d1a3c', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'weekend_day', '2025-05-25 11:38:16.276+00', '2025-05-25 11:40:04.32+00', false, '2025-05-25 11:38:16.337621+00', '2025-05-25 12:42:22.502735+00'),
	('ab70f869-2f17-41d3-be95-19f0eaae29cd', 'a9d969e3-d449-4005-a679-f63be07c6872', 'weekend_day', '2025-05-25 11:41:09.381+00', '2025-05-25 11:43:49.437+00', false, '2025-05-25 11:41:09.436332+00', '2025-05-25 12:42:22.502735+00'),
	('8279b300-d6f1-4447-b963-c25afdd7e9bb', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-25 11:40:15.909+00', '2025-05-25 11:43:52.778+00', false, '2025-05-25 11:40:15.956583+00', '2025-05-25 12:42:22.502735+00'),
	('de3ec1ce-1a8c-488d-adef-e60463c7f14d', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'weekend_day', '2025-05-25 11:44:11.049+00', '2025-05-25 11:53:12.845+00', false, '2025-05-25 11:44:11.100457+00', '2025-05-25 12:42:22.502735+00'),
	('63b0c33e-6859-4000-961d-2ff98d4a97a1', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-25 12:08:39.778+00', '2025-05-25 12:29:52.914+00', false, '2025-05-25 12:08:39.858848+00', '2025-05-25 12:42:22.502735+00'),
	('6177c26f-e16a-4b5b-86e1-8c862a863ae6', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'weekend_day', '2025-05-25 11:53:17.915+00', '2025-05-25 12:29:58.164+00', false, '2025-05-25 11:53:17.955365+00', '2025-05-25 12:42:22.502735+00'),
	('a909dabd-1865-472f-b914-cc916f1ff4e2', 'a9d969e3-d449-4005-a679-f63be07c6872', 'weekend_day', '2025-05-25 11:55:00.193+00', '2025-05-25 12:30:01.895+00', false, '2025-05-25 11:55:00.262735+00', '2025-05-25 12:42:22.502735+00'),
	('be77bf3d-252a-4611-a3e4-f1055116adc5', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-25 12:02:52.119+00', '2025-05-25 12:30:05.245+00', false, '2025-05-25 12:02:52.188814+00', '2025-05-25 12:42:22.502735+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d491', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-05-23 05:24:46.89275+00', '2025-05-23 14:15:54.406+00', false, '2025-05-23 08:24:46.89275+00', '2025-05-25 12:42:22.502735+00'),
	('17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_night', '2025-05-23 13:17:58.966+00', '2025-05-23 14:16:51.017+00', false, '2025-05-23 13:17:59.136287+00', '2025-05-25 12:42:22.502735+00'),
	('83ae47bc-571a-4301-b305-5bd0172d2baa', 'a9d969e3-d449-4005-a679-f63be07c6872', 'weekend_night', '2025-05-25 12:08:49.159+00', '2025-05-25 12:29:48.302+00', false, '2025-05-25 12:08:49.215181+00', '2025-05-25 12:42:22.502735+00'),
	('81057312-aba3-40ca-bf50-2ca0dd0116d1', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-25 13:05:41.222+00', '2025-05-25 13:12:29.409+00', false, '2025-05-25 13:05:41.368796+00', '2025-05-25 13:12:29.552285+00'),
	('1ab80df0-08de-44e3-83b3-fbcc5f2ee8f9', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-25 12:30:12.008+00', '2025-05-25 13:12:33.163+00', false, '2025-05-25 12:30:12.124761+00', '2025-05-25 13:12:33.32139+00'),
	('fbd23474-1bff-44bf-9d76-60db7ab0ccf3', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-25 12:46:51.09+00', '2025-05-25 13:12:37.281+00', false, '2025-05-25 12:46:51.21251+00', '2025-05-25 13:12:37.445207+00'),
	('e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-25 13:18:43.507+00', '2025-05-25 14:06:54.579+00', false, '2025-05-25 13:18:43.662061+00', '2025-05-25 14:06:54.674344+00'),
	('3ea11261-194f-4e54-857f-0282c04ff2a9', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-25 13:12:43.167+00', '2025-05-25 14:06:59.697+00', false, '2025-05-25 13:12:43.302387+00', '2025-05-25 14:06:59.862134+00'),
	('5942f627-345a-427d-86bb-7e68758b8e64', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-25 14:07:13.91+00', '2025-05-25 14:24:17.731+00', false, '2025-05-25 14:07:13.984348+00', '2025-05-25 14:24:17.860639+00'),
	('2d4b5fdc-e517-4926-8675-c818f1c01c36', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-25 14:39:37.841+00', '2025-05-26 07:39:07.254+00', false, '2025-05-25 14:39:37.869706+00', '2025-05-26 07:39:07.384423+00'),
	('07f4a22d-ce11-4aee-8a2f-e203e40c5308', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-25 14:36:46.631+00', '2025-05-26 07:39:12.373+00', false, '2025-05-25 14:36:46.69003+00', '2025-05-26 07:39:12.570123+00'),
	('bd2698e6-1eb2-481f-85c3-85a171ce5883', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'weekend_day', '2025-05-25 14:25:30.701+00', '2025-05-26 07:39:17.114+00', false, '2025-05-25 14:25:30.779564+00', '2025-05-26 07:39:17.315822+00'),
	('fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-25 14:24:28.322+00', '2025-05-26 07:39:22.524+00', false, '2025-05-25 14:24:28.385231+00', '2025-05-26 07:39:22.650407+00'),
	('48a0f847-9f15-4840-88e2-3186d0f93165', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'weekend_night', '2025-05-25 14:25:39.421+00', '2025-05-26 07:39:31.071+00', false, '2025-05-25 14:25:39.473684+00', '2025-05-26 07:39:31.197259+00'),
	('d0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_night', '2025-05-25 14:25:23.266+00', '2025-05-26 07:39:35.595+00', false, '2025-05-25 14:25:23.328499+00', '2025-05-26 07:39:35.731542+00'),
	('90ed86ab-c853-40e3-93bc-194b7e0dee29', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-26 07:39:48.668+00', '2025-05-26 08:00:39.918+00', false, '2025-05-26 07:39:48.804854+00', '2025-05-26 09:06:06.926203+00'),
	('75b41eb1-57f6-4523-83d3-f00f3314f92b', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-26 08:01:00.613+00', '2025-05-26 09:24:02.053+00', false, '2025-05-26 09:06:27.597634+00', '2025-05-26 09:24:02.161247+00'),
	('f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-26 09:24:10.175+00', '2025-05-26 10:10:42.678+00', false, '2025-05-26 09:24:10.244347+00', '2025-05-26 10:10:42.775397+00'),
	('352e76ca-6696-49f5-8602-f2b1c793848e', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-26 10:11:50.997+00', '2025-05-26 10:32:17.157+00', false, '2025-05-26 10:11:51.10612+00', '2025-05-26 10:32:17.252418+00'),
	('8829d17a-4c37-4f58-95b4-c66db25fd3bf', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-26 10:32:52.032+00', '2025-05-26 10:45:06.865+00', false, '2025-05-26 10:32:52.108632+00', '2025-05-26 10:45:06.934596+00'),
	('1b9bde2e-6188-400a-a9c5-3da628ca9e9b', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-26 10:46:36.894+00', '2025-05-26 10:47:30.401+00', false, '2025-05-26 10:46:36.971147+00', '2025-05-26 10:47:30.509268+00'),
	('042b8c4c-a57f-4371-bca3-b17daabf0034', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-26 12:03:52.892+00', '2025-05-26 12:35:15.312+00', false, '2025-05-26 12:03:52.936764+00', '2025-05-26 12:35:15.397166+00'),
	('a60777ff-53df-4de3-9623-9929dfa06b81', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-26 11:50:34.076+00', '2025-05-26 12:35:19.892+00', false, '2025-05-26 11:50:34.214123+00', '2025-05-26 12:35:19.968298+00');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('e3b4d14a-e8ef-4b68-a02f-c9fce6068024', '2d4b5fdc-e517-4926-8675-c818f1c01c36', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-25 14:41:30.745967+00', '2025-05-25 14:41:30.745967+00'),
	('5bbc0e42-da5e-4a73-862a-5748da2869db', '2d4b5fdc-e517-4926-8675-c818f1c01c36', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 14:41:30.83919+00', '2025-05-25 14:41:30.83919+00'),
	('0c72ef0b-5e3b-421b-8e13-2f84ef1d2ef2', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('ed5f6696-e09e-442a-b5d2-93df694b30c0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('85bb9b91-0761-429a-9cd6-3ef4f3a1d0ae', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 14:42:38.755592+00', '2025-05-25 14:42:38.755592+00'),
	('77ad0641-7249-4540-a38c-33995c36b5a2', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-26 07:39:09.478847+00', '2025-05-26 07:39:09.478847+00'),
	('1f62f634-3e63-4004-ac08-c955b9b135ff', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', '831035d1-93e9-4683-af25-b40c2332b2fe', '22:00:00', '06:00:00', '#34A853', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('642913f5-c724-49d0-97df-9f6a3424c8c0', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 07:39:09.566768+00', '2025-05-26 07:39:09.566768+00'),
	('3d4a8faf-8b68-490b-ac1f-871cd36ebc60', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-26 07:39:19.662518+00', '2025-05-26 07:39:19.662518+00'),
	('d4bd5026-5f09-479b-9cdb-211f9d039c20', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 07:39:19.755673+00', '2025-05-26 07:39:19.755673+00'),
	('9b4c35e0-0449-4b81-b970-d98cb102cfce', '48a0f847-9f15-4840-88e2-3186d0f93165', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 07:39:28.244908+00', '2025-05-26 07:39:28.244908+00'),
	('50a6c1ff-d962-4c7c-bd14-bcdf71b987c1', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 09:06:27.652014+00', '2025-05-26 09:06:27.652014+00'),
	('7c495d1b-cfc1-4f79-87df-f11dd0e828c5', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('84aacfe3-2fae-4969-9b30-b21501a35384', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('df84916e-7504-4641-9b18-1ddbf9479843', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 09:06:27.745213+00', '2025-05-26 09:06:27.745213+00'),
	('e49314b2-08c5-4e31-9c69-fea30d4ca79d', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 09:24:10.288256+00', '2025-05-26 09:24:10.288256+00'),
	('feacaca2-d674-462a-b8db-081357e6ba7f', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 09:24:10.378291+00', '2025-05-26 09:24:10.378291+00'),
	('3d7e1f85-96e4-4e70-91c6-83741235a39e', '352e76ca-6696-49f5-8602-f2b1c793848e', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 10:11:51.194607+00', '2025-05-26 10:11:51.194607+00'),
	('cf40e7aa-4741-4c44-9256-d31abdc16131', '352e76ca-6696-49f5-8602-f2b1c793848e', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 10:11:51.30854+00', '2025-05-26 10:11:51.30854+00'),
	('f45f2a95-202c-4d22-a185-cae48776a7b3', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 10:32:52.165677+00', '2025-05-26 10:32:52.165677+00'),
	('b2ad2268-c8c5-4680-a679-d86a0af9d6b3', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('c985afd7-408c-425d-bba5-e1474e1b942b', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 10:32:52.267283+00', '2025-05-26 10:32:52.267283+00'),
	('b767566b-5d75-4ccb-86ae-0efef2a4dd16', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('f14e083c-34de-42d9-adf1-2537d5a5873e', '1b9bde2e-6188-400a-a9c5-3da628ca9e9b', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 10:46:37.069729+00', '2025-05-26 10:46:37.069729+00'),
	('beb6bf4a-8f29-45eb-97f0-959afb6fded0', 'a60777ff-53df-4de3-9623-9929dfa06b81', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 11:50:34.214123+00', '2025-05-26 11:50:34.214123+00'),
	('fee328ae-3905-4f62-9604-7e9e36e80e19', 'a60777ff-53df-4de3-9623-9929dfa06b81', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 11:50:34.470698+00', '2025-05-26 11:50:34.470698+00'),
	('d64e90ba-3e4f-48e8-a8db-478b59144bce', '042b8c4c-a57f-4371-bca3-b17daabf0034', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 12:03:53.013175+00', '2025-05-26 12:03:53.013175+00'),
	('20a26eee-e877-4df4-b1c2-18f4f20c1d04', '2d4b5fdc-e517-4926-8675-c818f1c01c36', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 14:41:30.696155+00', '2025-05-25 14:41:30.696155+00'),
	('fe251808-49dd-48e3-9938-baf0daefae3d', '2d4b5fdc-e517-4926-8675-c818f1c01c36', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 14:41:30.8015+00', '2025-05-25 14:41:30.8015+00'),
	('297de4c0-b1a7-406a-80c6-b6627336674e', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-05-25 14:42:38.706919+00', '2025-05-25 14:42:38.706919+00'),
	('ad19a48f-53e7-4b5e-9091-630495595253', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 07:39:09.424589+00', '2025-05-26 07:39:09.424589+00'),
	('6d611651-5d8b-4995-ac83-50291520e2f5', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 07:39:09.522371+00', '2025-05-26 07:39:09.522371+00'),
	('7fa3b3cf-4e67-4a16-93e8-1258205c20ae', 'bd2698e6-1eb2-481f-85c3-85a171ce5883', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 07:39:14.377614+00', '2025-05-26 07:39:14.377614+00'),
	('9ba9d822-030e-433f-ab1e-39acc7d47c32', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 07:39:19.619411+00', '2025-05-26 07:39:19.619411+00'),
	('28dd2450-5773-4d40-bcca-2ae26992de82', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 07:39:19.710939+00', '2025-05-26 07:39:19.710939+00'),
	('fc24164d-776c-46c2-acf4-456dbb1c8e02', '90ed86ab-c853-40e3-93bc-194b7e0dee29', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 07:39:48.865559+00', '2025-05-26 07:39:48.865559+00'),
	('0efbceb9-efa2-48e2-ae08-8f2dbe323e32', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-26 09:06:27.696824+00', '2025-05-26 09:06:27.696824+00'),
	('a4c41fcc-b036-47e9-82a6-8dfaf5345b07', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 09:06:27.787943+00', '2025-05-26 09:06:27.787943+00'),
	('3ebbc53f-58ea-4218-bb64-fa84cb100fad', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-26 09:24:10.336658+00', '2025-05-26 09:24:10.336658+00'),
	('041dc4e7-598f-41de-81cd-b1039a11d3c8', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 09:24:10.429497+00', '2025-05-26 09:24:10.429497+00'),
	('6754d0ee-c43b-4f44-8e41-ff1580d74304', '352e76ca-6696-49f5-8602-f2b1c793848e', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-26 10:11:51.251623+00', '2025-05-26 10:11:51.251623+00'),
	('a9da667f-072b-46f7-8a58-38787ef942cc', '352e76ca-6696-49f5-8602-f2b1c793848e', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 10:11:51.368983+00', '2025-05-26 10:11:51.368983+00'),
	('94c91525-2cd4-407a-9a87-5aee4ecde03e', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-26 10:32:52.220533+00', '2025-05-26 10:32:52.220533+00'),
	('7c8a3afd-d3db-458e-bc85-df25648aa21e', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 10:32:52.320673+00', '2025-05-26 10:32:52.320673+00'),
	('c93322a4-90a3-45be-a647-a4176b207f52', '1b9bde2e-6188-400a-a9c5-3da628ca9e9b', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 10:46:37.224163+00', '2025-05-26 10:46:37.224163+00'),
	('a4a755bf-1a9e-4c6d-a13c-6e0d895668fb', 'a60777ff-53df-4de3-9623-9929dfa06b81', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 11:50:34.381017+00', '2025-05-26 11:50:34.381017+00'),
	('6dc5009b-c2f7-4c91-88dc-8ad694eb5504', '042b8c4c-a57f-4371-bca3-b17daabf0034', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 12:03:52.936764+00', '2025-05-26 12:03:52.936764+00'),
	('a1621d3a-a20d-4687-9313-4a0b1ddaa15b', '042b8c4c-a57f-4371-bca3-b17daabf0034', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-26 12:03:53.072319+00', '2025-05-26 12:03:53.072319+00');


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_porter_assignments" ("id", "shift_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('52e50248-1ce0-4cd3-946a-1b4584d113ec', '94c91525-2cd4-407a-9a87-5aee4ecde03e', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '11:00:00', '18:00:00', '2025-05-26 10:35:02.921496+00', '2025-05-26 10:35:02.921496+00'),
	('67e605cc-67d6-48c2-b728-7499e7b2a77c', 'f14e083c-34de-42d9-adf1-2537d5a5873e', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-26 10:46:37.147765+00', '2025-05-26 10:46:37.147765+00');


--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '16:00:00', '#34A853', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#EA4335', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00');


--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_porter_pool" ("id", "shift_id", "porter_id", "created_at", "updated_at") VALUES
	('29186471-3b2d-483f-ad12-88377f097095', 'f9f8c607-d370-4ed8-94f0-dcee9f9be460', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '2025-05-25 11:30:14.12603+00', '2025-05-25 11:30:14.12603+00'),
	('b669dc3b-ab42-4b29-aa80-2a27b16f8d39', '63b0c33e-6859-4000-961d-2ff98d4a97a1', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-25 12:27:55.497707+00', '2025-05-25 12:27:55.497707+00'),
	('d22d10bf-1187-4a12-a02a-c53b05af95a2', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '2025-05-25 13:51:57.835398+00', '2025-05-25 13:51:57.835398+00'),
	('9e940659-5001-4384-b242-ab67f9d4b6d1', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-25 13:51:57.888194+00', '2025-05-25 13:51:57.888194+00'),
	('6da03ba3-e31b-4b2b-807f-e22381bee0d2', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-25 13:51:57.954102+00', '2025-05-25 13:51:57.954102+00'),
	('1c0d68d2-4f91-4ea0-a764-110d2d3b42a3', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-25 14:43:07.84465+00', '2025-05-25 14:43:07.84465+00'),
	('68030402-b07e-451b-bac4-a4ac06e3604c', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-25 14:43:07.896422+00', '2025-05-25 14:43:07.896422+00'),
	('2731ac06-8086-4229-84c2-618eed39d928', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-25 14:43:07.944042+00', '2025-05-25 14:43:07.944042+00'),
	('684b5213-d9be-451d-9660-85ab1a0db02e', '90ed86ab-c853-40e3-93bc-194b7e0dee29', '2e74429e-2aab-4bed-a979-6ccbdef74596', '2025-05-26 07:41:47.982682+00', '2025-05-26 07:41:47.982682+00'),
	('88916ef0-30c0-4828-b9cb-ba876c5a4f83', '90ed86ab-c853-40e3-93bc-194b7e0dee29', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-26 07:41:48.054002+00', '2025-05-26 07:41:48.054002+00'),
	('e9922a13-cdc6-43e1-94ac-9824179fe982', '90ed86ab-c853-40e3-93bc-194b7e0dee29', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-26 07:41:48.118678+00', '2025-05-26 07:41:48.118678+00'),
	('cb191517-e81b-4f3d-beca-e763b53a3b72', '90ed86ab-c853-40e3-93bc-194b7e0dee29', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-26 07:41:48.180463+00', '2025-05-26 07:41:48.180463+00'),
	('bc0917a6-ef65-457c-ba9d-66bdcea915f7', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-26 09:06:50.782297+00', '2025-05-26 09:06:50.782297+00'),
	('38205a4b-12d6-4ac1-a9bf-b39c39a2c381', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-26 09:06:50.837908+00', '2025-05-26 09:06:50.837908+00'),
	('b46a72fb-6194-4acc-880b-b9c677557211', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '2e74429e-2aab-4bed-a979-6ccbdef74596', '2025-05-26 09:06:50.882358+00', '2025-05-26 09:06:50.882358+00'),
	('3d4a36aa-da0f-4c1c-bef5-7a37f48f32e3', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '2025-05-26 09:06:50.93418+00', '2025-05-26 09:06:50.93418+00'),
	('16fbe27e-a24a-485c-b905-40a047875674', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-26 09:06:50.982346+00', '2025-05-26 09:06:50.982346+00'),
	('cbc147cc-292c-48db-b49d-1bee4e967482', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-26 09:06:51.032431+00', '2025-05-26 09:06:51.032431+00'),
	('63cecec9-a132-407d-a78f-b84c8516f1eb', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-26 09:06:51.084998+00', '2025-05-26 09:06:51.084998+00'),
	('767341e3-3dc6-4936-91f4-1613d0db45d2', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-05-26 09:06:51.130648+00', '2025-05-26 09:06:51.130648+00'),
	('a18f3a9b-36b6-4e89-9552-cfe684bc02e7', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '2025-05-26 09:06:51.175557+00', '2025-05-26 09:06:51.175557+00'),
	('1c40b171-ffce-476c-873c-f0fda44469e8', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '2025-05-26 09:06:51.220384+00', '2025-05-26 09:06:51.220384+00'),
	('563d37d8-59a8-43b5-8d19-64b81316a134', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '2025-05-26 09:06:51.264369+00', '2025-05-26 09:06:51.264369+00'),
	('c9d7b858-dde1-459a-9987-d3116909a66a', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '2025-05-26 09:06:51.30622+00', '2025-05-26 09:06:51.30622+00'),
	('9aa6e218-949d-4746-a111-d5efcb84475e', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '394d8660-7946-4b31-87c9-b60f7e1bc294', '2025-05-26 09:06:51.347306+00', '2025-05-26 09:06:51.347306+00'),
	('37714749-2336-4b16-a546-9ab819b9e4e8', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '12055968-78d3-4404-a05f-10e039217936', '2025-05-26 09:06:51.3929+00', '2025-05-26 09:06:51.3929+00'),
	('8a22d87d-7234-4eaa-89ae-82832abe9979', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '8b3b3e97-ea54-4c40-884b-04d3d24dbe23', '2025-05-26 09:06:51.440735+00', '2025-05-26 09:06:51.440735+00'),
	('58a141ce-6fa3-4fc7-ab18-688ae337e253', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '2025-05-26 09:06:51.494134+00', '2025-05-26 09:06:51.494134+00'),
	('b12ae8bc-ae62-4b47-a5d5-b099be91fecc', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'e55b1013-7e79-4e38-913e-c53de591f85c', '2025-05-26 09:06:51.544547+00', '2025-05-26 09:06:51.544547+00'),
	('8eea6d07-fcd7-42cb-8db5-654559387d25', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '2025-05-26 09:06:51.59312+00', '2025-05-26 09:06:51.59312+00'),
	('cfaf945c-8fc2-4c76-a22e-a200511b083d', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '69766d05-49d7-4e7c-8734-e3dc8949bf91', '2025-05-26 09:06:51.637786+00', '2025-05-26 09:06:51.637786+00'),
	('c768e8a8-49e4-46bf-8ee2-b287342a806b', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-26 09:06:51.683716+00', '2025-05-26 09:06:51.683716+00'),
	('c0a1d0bf-788d-452f-bf0d-4f2cb87fcece', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-26 09:53:55.552823+00', '2025-05-26 09:53:55.552823+00'),
	('459b3873-b3d5-4d91-8820-4307797cf5cd', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-26 09:53:55.635058+00', '2025-05-26 09:53:55.635058+00'),
	('e18361d3-8e38-4341-bb58-409925299c44', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-05-26 09:53:55.703341+00', '2025-05-26 09:53:55.703341+00'),
	('05f7e9d9-f3a2-4367-9a64-8685da3ac34c', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-26 10:34:52.663721+00', '2025-05-26 10:34:52.663721+00');


--
-- Data for Name: shift_support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_assignments" ("id", "shift_id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('10447215-8d92-431a-a305-22a859c41b2e', 'cc6d807e-7cb1-4e6f-8084-7068760d1a3c', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 11:38:16.784215+00', '2025-05-25 11:38:16.784215+00'),
	('7d45ab7c-4f05-417c-bfa5-2537d7d8224f', 'cc6d807e-7cb1-4e6f-8084-7068760d1a3c', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 11:38:16.830641+00', '2025-05-25 11:38:16.830641+00'),
	('86255359-e74f-470e-98a2-9c74fa195b07', '8279b300-d6f1-4447-b963-c25afdd7e9bb', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 11:40:16.3072+00', '2025-05-25 11:40:16.3072+00'),
	('5b92bdbe-b26f-4654-a97f-b78dc111aab6', '8279b300-d6f1-4447-b963-c25afdd7e9bb', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 11:40:16.356004+00', '2025-05-25 11:40:16.356004+00'),
	('1f1d8677-dfcc-4559-abb8-45938a4feb51', 'ab70f869-2f17-41d3-be95-19f0eaae29cd', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 11:41:09.796748+00', '2025-05-25 11:41:09.796748+00'),
	('0e5f48ed-39d8-447c-b4d0-25f84f3971a9', 'ab70f869-2f17-41d3-be95-19f0eaae29cd', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 11:41:09.850955+00', '2025-05-25 11:41:09.850955+00'),
	('43d1d58d-3c39-4162-8437-fa793f349e76', 'de3ec1ce-1a8c-488d-adef-e60463c7f14d', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 11:44:11.427823+00', '2025-05-25 11:44:11.427823+00'),
	('adc5d761-6bb0-45b3-9657-e3b6a86cf774', 'de3ec1ce-1a8c-488d-adef-e60463c7f14d', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 11:44:11.475061+00', '2025-05-25 11:44:11.475061+00'),
	('ade62461-fa8b-4dd3-a71e-d9373a8bfe5b', '6177c26f-e16a-4b5b-86e1-8c862a863ae6', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 11:53:18.278759+00', '2025-05-25 11:53:18.278759+00'),
	('a0e0c281-3952-4a3a-8932-726a46f4160b', '6177c26f-e16a-4b5b-86e1-8c862a863ae6', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 11:53:18.318341+00', '2025-05-25 11:53:18.318341+00'),
	('b3ec1739-0072-44bc-8056-565c338ae817', 'a909dabd-1865-472f-b914-cc916f1ff4e2', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 11:55:00.658858+00', '2025-05-25 11:55:00.658858+00'),
	('6a1c40a2-bf77-4bb7-bfa8-67f56b6a80f8', 'a909dabd-1865-472f-b914-cc916f1ff4e2', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 11:55:00.702113+00', '2025-05-25 11:55:00.702113+00'),
	('3eea6e64-3fdc-49a5-9b85-6fd933e74a92', 'be77bf3d-252a-4611-a3e4-f1055116adc5', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 12:02:52.557344+00', '2025-05-25 12:02:52.557344+00'),
	('af85c4c6-f2d9-49ce-ad15-d3e571da59cb', 'be77bf3d-252a-4611-a3e4-f1055116adc5', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 12:02:52.604491+00', '2025-05-25 12:02:52.604491+00'),
	('621a9409-a345-4ded-8f02-4bda6daeb3cd', 'be77bf3d-252a-4611-a3e4-f1055116adc5', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:05:44.821841+00', '2025-05-25 12:05:44.821841+00'),
	('94c4a9ed-4fdd-4ec9-a3e5-1239be145485', '3ea11261-194f-4e54-857f-0282c04ff2a9', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 13:12:43.912923+00', '2025-05-25 13:12:43.912923+00'),
	('752b21d5-ff00-4a1d-9088-79f3e1712fcf', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 13:18:44.604867+00', '2025-05-25 13:18:44.604867+00'),
	('3f963afc-2825-468e-bf00-5032f06fb19d', '5942f627-345a-427d-86bb-7e68758b8e64', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 14:07:14.480004+00', '2025-05-25 14:07:14.480004+00'),
	('5271b47a-b6ca-4e46-bf3f-d1b223d0c680', '63b0c33e-6859-4000-961d-2ff98d4a97a1', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 12:08:40.353072+00', '2025-05-25 12:08:40.353072+00'),
	('c6863582-578d-4ae6-b7b9-554afb549fb0', '63b0c33e-6859-4000-961d-2ff98d4a97a1', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 12:08:40.400314+00', '2025-05-25 12:08:40.400314+00'),
	('542c831f-9180-4d7f-82c5-ccc8266a040e', '5942f627-345a-427d-86bb-7e68758b8e64', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 14:07:14.830134+00', '2025-05-25 14:07:14.830134+00'),
	('e6fbf7fd-c2ba-478c-87b8-e5533ab858a1', '63b0c33e-6859-4000-961d-2ff98d4a97a1', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:08:41.251543+00', '2025-05-25 12:08:41.251543+00'),
	('7492c3fb-4191-4c83-9d10-5ec46f36924e', '83ae47bc-571a-4301-b305-5bd0172d2baa', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 12:08:49.606777+00', '2025-05-25 12:08:49.606777+00'),
	('141894c9-6f0e-4476-b117-42d1f19cb43c', '83ae47bc-571a-4301-b305-5bd0172d2baa', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:08:49.646279+00', '2025-05-25 12:08:49.646279+00'),
	('36f2cd96-3e26-483e-9ec3-31fe7a8769e1', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 14:24:29.344034+00', '2025-05-25 14:24:29.344034+00'),
	('b94e38fd-dbb2-42db-8dd1-a038aac698db', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '20:00:00', '04:00:00', '#FBBC05', '2025-05-25 14:25:24.012307+00', '2025-05-25 14:25:24.012307+00'),
	('a1856f81-64f6-48c2-bb1c-f607b385d26f', '48a0f847-9f15-4840-88e2-3186d0f93165', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 14:25:40.040136+00', '2025-05-25 14:25:40.040136+00'),
	('06dc3310-e99b-4917-9dce-26eb4fee6a02', '48a0f847-9f15-4840-88e2-3186d0f93165', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 14:25:40.149133+00', '2025-05-25 14:25:40.149133+00'),
	('bbd773bb-0bf5-4e02-b8a7-b14de2870209', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 14:36:47.351576+00', '2025-05-25 14:36:47.351576+00'),
	('f935f7c0-e8bd-4915-9feb-b7376c2d6108', '2d4b5fdc-e517-4926-8675-c818f1c01c36', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 14:39:38.42059+00', '2025-05-25 14:39:38.42059+00'),
	('e5ee5931-0626-4318-acdd-71938494f1fc', '90ed86ab-c853-40e3-93bc-194b7e0dee29', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 07:39:49.413857+00', '2025-05-26 07:39:49.413857+00'),
	('679f35b6-74c9-43b8-9367-a28d65c74ac8', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-26 09:06:28.404884+00', '2025-05-26 09:06:28.404884+00'),
	('8d387fe0-e025-46a8-a267-38cf28c22aba', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-26 09:24:10.884119+00', '2025-05-26 09:24:10.884119+00'),
	('2404a7cc-87a2-4662-97f1-d6193da28e8b', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 09:24:11.219954+00', '2025-05-26 09:24:11.219954+00'),
	('6297257b-612f-4997-bb22-fd8832dc3848', '352e76ca-6696-49f5-8602-f2b1c793848e', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 10:11:52.149202+00', '2025-05-26 10:11:52.149202+00'),
	('d89a7704-84a8-4a11-acb7-6614571817cb', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-26 10:32:53.006134+00', '2025-05-26 10:32:53.006134+00'),
	('f8d2e76c-5353-4da6-a4e3-a9b25b0a4f28', '1b9bde2e-6188-400a-a9c5-3da628ca9e9b', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 10:46:37.895149+00', '2025-05-26 10:46:37.895149+00'),
	('3710e166-cf4d-427d-824b-91ccb7e4d481', 'a60777ff-53df-4de3-9623-9929dfa06b81', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 11:50:35.919664+00', '2025-05-26 11:50:35.919664+00'),
	('707e6790-ef8d-41e0-ad20-da699dfb97b8', '6177c26f-e16a-4b5b-86e1-8c862a863ae6', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:29:56.378678+00', '2025-05-25 12:29:56.378678+00'),
	('aed597c5-44a4-4965-84d3-cf869bf5c592', 'a909dabd-1865-472f-b914-cc916f1ff4e2', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:30:00.048788+00', '2025-05-25 12:30:00.048788+00'),
	('ca87ecf9-5979-4610-84e4-42cd4fdcc928', '1ab80df0-08de-44e3-83b3-fbcc5f2ee8f9', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 12:30:12.481187+00', '2025-05-25 12:30:12.481187+00'),
	('c211ca71-1bb7-437f-ac57-c2872dc7db3f', '1ab80df0-08de-44e3-83b3-fbcc5f2ee8f9', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:30:12.514725+00', '2025-05-25 12:30:12.514725+00'),
	('1adf7b60-4efb-48e9-8b20-275ac121ce80', 'fbd23474-1bff-44bf-9d76-60db7ab0ccf3', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 12:46:51.782691+00', '2025-05-25 12:46:51.782691+00'),
	('b642d610-89b8-4870-a6a6-4819037b5623', 'fbd23474-1bff-44bf-9d76-60db7ab0ccf3', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 12:46:51.834692+00', '2025-05-25 12:46:51.834692+00'),
	('8892f880-19db-400e-b878-816244e65709', 'fbd23474-1bff-44bf-9d76-60db7ab0ccf3', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 13:02:11.328564+00', '2025-05-25 13:02:11.328564+00'),
	('f0028113-0389-46f4-b9f7-eb9615121830', 'fbd23474-1bff-44bf-9d76-60db7ab0ccf3', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 13:02:11.370749+00', '2025-05-25 13:02:11.370749+00'),
	('73e65502-56e5-42b2-9a2c-b1080b50c375', 'fbd23474-1bff-44bf-9d76-60db7ab0ccf3', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 13:02:11.410927+00', '2025-05-25 13:02:11.410927+00'),
	('688ec05a-abcd-4662-ba16-f75864b18858', '1ab80df0-08de-44e3-83b3-fbcc5f2ee8f9', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 13:12:31.6227+00', '2025-05-25 13:12:31.6227+00'),
	('f6ab48c6-df5f-4ad6-a24c-6e65f7244c21', '3ea11261-194f-4e54-857f-0282c04ff2a9', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 13:12:43.818201+00', '2025-05-25 13:12:43.818201+00'),
	('27505ce4-540a-4527-a585-c6f5d9d5c539', '3ea11261-194f-4e54-857f-0282c04ff2a9', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 13:12:44.009728+00', '2025-05-25 13:12:44.009728+00'),
	('05851351-6d59-42dd-a730-6144b082d1d4', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 13:18:44.717344+00', '2025-05-25 13:18:44.717344+00'),
	('bd28b720-368f-4de5-9276-394dc058868e', '5942f627-345a-427d-86bb-7e68758b8e64', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 14:07:14.604341+00', '2025-05-25 14:07:14.604341+00'),
	('64b0a929-8e3e-4e3e-b01d-f4b3e700c591', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 14:24:29.065411+00', '2025-05-25 14:24:29.065411+00'),
	('328488c6-c784-4369-9753-bd99003cbefc', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 14:24:29.4972+00', '2025-05-25 14:24:29.4972+00'),
	('1ebd46d0-dd34-49a2-bafe-fa01bc015b67', 'bd2698e6-1eb2-481f-85c3-85a171ce5883', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 14:25:31.231987+00', '2025-05-25 14:25:31.231987+00'),
	('cb63f4af-bd3f-47ec-a89e-1c55175cfc7b', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 14:36:47.149622+00', '2025-05-25 14:36:47.149622+00'),
	('f13b8a52-7c6d-4c0f-b03d-febf9dbde1fa', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 14:36:47.449206+00', '2025-05-25 14:36:47.449206+00'),
	('9b951153-c659-4c04-821f-23787f5de79e', '2d4b5fdc-e517-4926-8675-c818f1c01c36', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 14:39:38.515829+00', '2025-05-25 14:39:38.515829+00'),
	('57588f96-845d-468c-9e6e-34bdc3c5e665', '90ed86ab-c853-40e3-93bc-194b7e0dee29', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-26 07:39:49.54085+00', '2025-05-26 07:39:49.54085+00'),
	('22bc8197-45ef-4a33-8248-2fa3fe1a1e35', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 09:06:28.515942+00', '2025-05-26 09:06:28.515942+00'),
	('d4c033b1-d5f7-4f65-8fe1-e11bb75fc692', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 09:24:10.995628+00', '2025-05-26 09:24:10.995628+00'),
	('f1fedd1c-82a2-4ed9-b7df-e6d98eb8b7a9', '352e76ca-6696-49f5-8602-f2b1c793848e', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 10:11:51.918796+00', '2025-05-26 10:11:51.918796+00'),
	('3422cb05-3891-4bc9-aa45-977a2e062962', '352e76ca-6696-49f5-8602-f2b1c793848e', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-26 10:11:52.256489+00', '2025-05-26 10:11:52.256489+00'),
	('ffc5376b-8c4f-45ea-95ef-28b162f8d5d8', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 10:32:53.136227+00', '2025-05-26 10:32:53.136227+00'),
	('b9507a76-9f08-400e-9096-d6693962c5be', '1b9bde2e-6188-400a-a9c5-3da628ca9e9b', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 10:46:38.254059+00', '2025-05-26 10:46:38.254059+00'),
	('517a4fb3-f43a-448e-9355-212cc7661077', '042b8c4c-a57f-4371-bca3-b17daabf0034', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 12:03:52.936764+00', '2025-05-26 12:03:52.936764+00'),
	('28aa6286-e1a7-435a-bb1f-11da98632c59', '3ea11261-194f-4e54-857f-0282c04ff2a9', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 13:12:43.728646+00', '2025-05-25 13:12:43.728646+00'),
	('f07085ef-9b4c-4e80-ab82-e6363b1e4628', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 13:18:44.478249+00', '2025-05-25 13:18:44.478249+00'),
	('8f5c2e9c-6f09-45aa-a6b2-fee1d6380de0', 'e003f89c-2f7b-44ce-8c80-0eeb3d6e772a', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 13:18:44.828091+00', '2025-05-25 13:18:44.828091+00'),
	('3c42d998-64dd-467d-bbbd-d919001928a7', '5942f627-345a-427d-86bb-7e68758b8e64', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 14:07:14.714892+00', '2025-05-25 14:07:14.714892+00'),
	('d0965992-a67b-4d82-979a-88fb8061bd88', 'fb68d5ff-c15c-4f5c-9ed4-e70470c9f9b8', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 14:24:29.208462+00', '2025-05-25 14:24:29.208462+00'),
	('f360c72a-47c8-4a69-872a-7913c5da8f0d', '81057312-aba3-40ca-bf50-2ca0dd0116d1', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 13:05:41.7126+00', '2025-05-25 13:05:41.7126+00'),
	('2a42d44e-3365-4165-bc1a-39230571b3d5', '81057312-aba3-40ca-bf50-2ca0dd0116d1', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 13:05:41.75571+00', '2025-05-25 13:05:41.75571+00'),
	('d6f1e012-68e3-4378-9e50-2bd30a335ac1', '81057312-aba3-40ca-bf50-2ca0dd0116d1', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 13:05:41.794949+00', '2025-05-25 13:05:41.794949+00'),
	('10680b18-0f4d-4440-b2d1-c7737b0d87a0', '81057312-aba3-40ca-bf50-2ca0dd0116d1', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 13:05:41.833525+00', '2025-05-25 13:05:41.833525+00'),
	('f94ea4e3-dbd2-4f9b-9f62-0b0c7a448afe', 'd0dce33e-c8f5-4364-8c2c-5d9cc6edb933', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 14:25:23.902457+00', '2025-05-25 14:25:23.902457+00'),
	('ae0f8171-43c0-43f7-b8d2-8cacfe5eecd2', 'bd2698e6-1eb2-481f-85c3-85a171ce5883', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 14:25:31.318252+00', '2025-05-25 14:25:31.318252+00'),
	('35ff3555-d74e-464e-a2e8-6ec3ad6a9ec3', '07f4a22d-ce11-4aee-8a2f-e203e40c5308', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 14:36:47.243939+00', '2025-05-25 14:36:47.243939+00'),
	('8769a019-d461-437b-ac9f-23b5a51fb6ec', '2d4b5fdc-e517-4926-8675-c818f1c01c36', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 14:39:38.320259+00', '2025-05-25 14:39:38.320259+00'),
	('bdb1578c-66ce-4c34-a1ee-b830e1b218b2', '2d4b5fdc-e517-4926-8675-c818f1c01c36', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 14:39:38.627583+00', '2025-05-25 14:39:38.627583+00'),
	('bc0b8c7c-f2ad-4e03-ad3b-d4599052b4f1', '75b41eb1-57f6-4523-83d3-f00f3314f92b', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 09:06:28.285828+00', '2025-05-26 09:06:28.285828+00'),
	('324fbd02-3df8-4375-9a8e-5b1fa86264da', '75b41eb1-57f6-4523-83d3-f00f3314f92b', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 09:06:28.626928+00', '2025-05-26 09:06:28.626928+00'),
	('810d39d7-3783-4324-bb49-140ee6564ee6', 'f2147e63-1bb4-4f91-bcae-aea21ff10cc6', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 09:24:11.114052+00', '2025-05-26 09:24:11.114052+00'),
	('a0bd780d-c736-4d96-93b1-c0fec77440e1', '352e76ca-6696-49f5-8602-f2b1c793848e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 10:11:52.023267+00', '2025-05-26 10:11:52.023267+00'),
	('4fc371c6-6223-458f-a70d-aaaaaddd1d01', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-26 10:32:52.883749+00', '2025-05-26 10:32:52.883749+00'),
	('421f4543-4649-4787-ac65-9f765d0343e9', '8829d17a-4c37-4f58-95b4-c66db25fd3bf', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-26 10:32:53.25907+00', '2025-05-26 10:32:53.25907+00'),
	('4f8d7709-4dde-4dfe-a90d-ee936e80cddc', 'a60777ff-53df-4de3-9623-9929dfa06b81', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 11:50:35.547754+00', '2025-05-26 11:50:35.547754+00'),
	('162e5e4b-74ab-408c-9f59-467a19b13144', '042b8c4c-a57f-4371-bca3-b17daabf0034', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-26 12:03:53.531519+00', '2025-05-26 12:03:53.531519+00');


--
-- Data for Name: shift_support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_porter_assignments" ("id", "shift_support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('13b6360c-2bb3-4d04-8308-2de50d400a25', 'f8d2e76c-5353-4da6-a4e3-a9b25b0a4f28', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-26 10:46:37.976752+00', '2025-05-26 10:46:37.976752+00'),
	('31bb98ec-42ea-4dc0-8f09-293deb1f949b', 'b9507a76-9f08-400e-9096-d6693962c5be', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-26 10:46:38.319174+00', '2025-05-26 10:46:38.319174+00'),
	('d488c6bd-14d9-4a77-80da-654d296eaed3', '4f8d7709-4dde-4dfe-a90d-ee936e80cddc', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-26 11:50:35.691855+00', '2025-05-26 11:50:35.691855+00'),
	('ed525372-7a9f-423a-a748-42e49ca66017', '3710e166-cf4d-427d-824b-91ccb7e4d481', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-26 11:50:36.011866+00', '2025-05-26 11:50:36.011866+00'),
	('e82b128b-eae0-4923-b4c9-cb3625cc107f', '517a4fb3-f43a-448e-9355-212cc7661077', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-26 12:03:52.936764+00', '2025-05-26 12:03:52.936764+00'),
	('5b5c5cfc-579e-4070-a03d-e624b778dcf0', '162e5e4b-74ab-408c-9f59-467a19b13144', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-26 12:03:53.570114+00', '2025-05-26 12:03:53.570114+00'),
	('d8b37e29-b2b8-40cb-ad6e-36a61af63ca7', '517a4fb3-f43a-448e-9355-212cc7661077', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-26 12:03:53.666585+00', '2025-05-26 12:03:53.666585+00');


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
	('1933a5d4-e02d-4301-b580-a0fdbdbfb21d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Walk', NULL, '2025-05-25 09:51:59.07475+00', '2025-05-25 09:51:59.07475+00');


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('37ef35c9-6670-494d-871a-8eb16248720e', 'eca831e9-fa9f-4604-9526-0a6f70040f86', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'pending', '2025-05-23 08:49:55.479887+00', '2025-05-24 14:10:28.733507+00', '07:33', '07:34', '07:53'),
	('5e939454-7477-43e5-b5f3-65675d3e0ec7', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', NULL, '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-23 06:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('a5638fbf-2bfe-4805-be92-13d3bdab7be0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-23 08:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('8f16befe-a495-4b05-840d-cc077a569ad3', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', NULL, 'completed', '2025-05-23 09:21:47.358281+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('724f2648-0b08-41a6-8321-91619e0dbabb', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', NULL, 'completed', '2025-05-23 07:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('6e25558d-f989-49ce-8d40-c5b69f1af256', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', NULL, NULL, 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('946c58f2-ba58-4df3-81ab-b43a29c31f77', '90ed86ab-c853-40e3-93bc-194b7e0dee29', 'f18bf0ce-835e-4d9d-92d0-119222a56f5e', '2e74429e-2aab-4bed-a979-6ccbdef74596', '52c4ae93-8ede-45d9-b5ff-d5e87b4f20aa', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'completed', '2025-05-26 07:41:38.627802+00', '2025-05-26 07:42:09.647724+00', '08:41', '08:42', '09:01');


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
	('33dc4387-f8a6-4e35-ae5d-303c806a7a71', '5c0c9e25-ae34-4872-8696-4c4ce6e76112', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', true, false, '2025-05-24 15:26:02.940817+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('067489a9-2cde-4791-a414-c4120ed0b08c', 'a97d8a74-0e16-4e1f-908e-96e935d91002', '52c4ae93-8ede-45d9-b5ff-d5e87b4f20aa', true, false, '2025-05-24 12:22:10.65484+00'),
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
