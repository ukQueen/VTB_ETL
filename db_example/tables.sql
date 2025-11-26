-- УРОВЕНЬ 1: БАЗОВЫЕ СУЩНОСТИ (без внешних ключей)
CREATE TABLE universities (
    university_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    founded_date DATE,
    accreditation_level VARCHAR(50)
);

CREATE TABLE faculties (
    faculty_id SERIAL PRIMARY KEY,
    university_id INTEGER,
    name VARCHAR(255) NOT NULL,
    dean_name VARCHAR(100),
    building_number VARCHAR(10)
);

CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    faculty_id INTEGER,
    name VARCHAR(255) NOT NULL,
    head_name VARCHAR(100),
    phone VARCHAR(20)
);

CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    birth_date DATE,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    enrollment_date DATE
);

-- УРОВЕНЬ 2: СЛОВАРИ (не зависят ни от кого)
CREATE TABLE academic_degree_types (
    degree_code VARCHAR(10) PRIMARY KEY,
    degree_name VARCHAR(100) NOT NULL,
    description TEXT,
    hierarchy_level INTEGER
);

CREATE TABLE course_types (
    type_code VARCHAR(10) PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL,
    is_required BOOLEAN DEFAULT true,
    credits_range INT4RANGE
);

CREATE TABLE countries (
    country_code VARCHAR(3) PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    region VARCHAR(50)
);

CREATE TABLE event_types (
    event_type_code VARCHAR(10) PRIMARY KEY,
    event_type_name VARCHAR(100) NOT NULL,
    category VARCHAR(50)
);

CREATE TABLE scholarship_types (
    type_code VARCHAR(10) PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL,
    min_amount DECIMAL(10,2),
    max_amount DECIMAL(10,2),
    requirements TEXT
);

CREATE TABLE project_statuses (
    status_code VARCHAR(10) PRIMARY KEY,
    status_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN
);

CREATE TABLE equipment_types (
    equipment_code VARCHAR(10) PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    avg_price DECIMAL(10,2)
);

CREATE TABLE week_days (
    day_code INTEGER PRIMARY KEY,
    day_name VARCHAR(15) NOT NULL,
    is_weekend BOOLEAN DEFAULT false
);

-- УРОВЕНЬ 3: ОСНОВНЫЕ ТАБЛИЦЫ С ПРОСТЫМИ ССЫЛКАМИ
CREATE TABLE professors (
    professor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    academic_degree VARCHAR(10) REFERENCES academic_degree_types(degree_code),
    email VARCHAR(255) UNIQUE,
    hire_date DATE,
    office_number VARCHAR(20)
);

CREATE TABLE study_programs (
    program_id SERIAL PRIMARY KEY,
    department_id INTEGER REFERENCES departments(department_id),
    name VARCHAR(255) NOT NULL,
    duration_years INTEGER,
    degree_type VARCHAR(50)
);

CREATE TABLE classrooms (
    classroom_id SERIAL PRIMARY KEY,
    building_id INTEGER,
    room_number VARCHAR(20),
    capacity INTEGER,
    equipment_type VARCHAR(100),
    is_laboratory BOOLEAN DEFAULT false
);

CREATE TABLE semesters (
    semester_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT false
);

-- УРОВЕНЬ 4: ТАБЛИЦЫ С БОЛЕЕ СЛОЖНЫМИ ССЫЛКАМИ
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    program_id INTEGER REFERENCES study_programs(program_id),
    name VARCHAR(255) NOT NULL,
    course_code VARCHAR(20) UNIQUE,
    course_type VARCHAR(10) REFERENCES course_types(type_code),
    credits INTEGER,
    description TEXT,
    course_level VARCHAR(50)
);

CREATE TABLE library_resources (
    resource_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255),
    resource_type VARCHAR(50),
    isbn VARCHAR(20),
    available_copies INTEGER,
    department_id INTEGER REFERENCES departments(department_id)
);

CREATE TABLE research_projects (
    project_id SERIAL PRIMARY KEY,
    department_id INTEGER REFERENCES departments(department_id),
    name VARCHAR(255) NOT NULL,
    budget DECIMAL(15,2),
    start_date DATE,
    end_date DATE,
    status_code VARCHAR(10) REFERENCES project_statuses(status_code),
    project_code VARCHAR(50) UNIQUE
);

CREATE TABLE student_groups (
    group_id SERIAL PRIMARY KEY,
    program_id INTEGER REFERENCES study_programs(program_id),
    name VARCHAR(50) NOT NULL,
    start_year INTEGER,
    curator_id INTEGER REFERENCES professors(professor_id)
);

-- УРОВЕНЬ 5: ТАБЛИЦЫ СВЯЗЕЙ МНОГИЕ-КО-МНОГИМ (ПЕРВАЯ ГРУППА)
CREATE TABLE professor_course_assignments (
    assignment_id SERIAL PRIMARY KEY,
    professor_id INTEGER NOT NULL REFERENCES professors(professor_id),
    course_id INTEGER NOT NULL REFERENCES courses(course_id),
    semester_id INTEGER NOT NULL REFERENCES semesters(semester_id),
    hours_per_week INTEGER,
    is_primary_instructor BOOLEAN DEFAULT true,
    UNIQUE(professor_id, course_id, semester_id)
);

CREATE TABLE student_course_enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id),
    course_id INTEGER NOT NULL REFERENCES courses(course_id),
    semester_id INTEGER NOT NULL REFERENCES semesters(semester_id),
    enrollment_date DATE DEFAULT CURRENT_DATE,
    enrollment_status VARCHAR(20) DEFAULT 'active',
    UNIQUE(student_id, course_id, semester_id)
);

CREATE TABLE professor_research_interests (
    interest_id SERIAL PRIMARY KEY,
    professor_id INTEGER NOT NULL REFERENCES professors(professor_id),
    research_field VARCHAR(200) NOT NULL,
    expertise_level VARCHAR(50),
    years_of_experience INTEGER,
    UNIQUE(professor_id, research_field)
);

CREATE TABLE student_extracurricular_activities (
    activity_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id),
    activity_type VARCHAR(100) NOT NULL,
    role VARCHAR(100),
    start_date DATE,
    end_date DATE,
    hours_per_week INTEGER,
    UNIQUE(student_id, activity_type, start_date)
);

CREATE TABLE course_prerequisites (
    prerequisite_id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL REFERENCES courses(course_id),
    required_course_id INTEGER NOT NULL REFERENCES courses(course_id),
    min_grade DECIMAL(4,2),
    is_mandatory BOOLEAN DEFAULT true,
    UNIQUE(course_id, required_course_id)
);

CREATE TABLE resource_keywords (
    keyword_id SERIAL PRIMARY KEY,
    resource_id INTEGER NOT NULL REFERENCES library_resources(resource_id),
    keyword VARCHAR(100) NOT NULL,
    UNIQUE(resource_id, keyword)
);

CREATE TABLE project_funding_sources (
    funding_id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES research_projects(project_id),
    funder_name VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2),
    funding_type VARCHAR(50),
    grant_number VARCHAR(100),
    UNIQUE(project_id, funder_name, grant_number)
);

-- УРОВЕНЬ 6: ДОПОЛНИТЕЛЬНЫЕ ТАБЛИЦЫ
CREATE TABLE grades (
    grade_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id),
    course_id INTEGER NOT NULL REFERENCES courses(course_id),
    professor_id INTEGER NOT NULL REFERENCES professors(professor_id),
    semester_id INTEGER NOT NULL REFERENCES semesters(semester_id),
    grade_value DECIMAL(4,2),
    grade_date DATE,
    exam_type VARCHAR(50)
);

CREATE TABLE scholarships (
    scholarship_id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(student_id),
    type_code VARCHAR(10) REFERENCES scholarship_types(type_code),
    amount DECIMAL(10,2),
    start_date DATE,
    end_date DATE,
    application_date DATE,
    status VARCHAR(20) DEFAULT 'active'
);

CREATE TABLE international_partnerships (
    partnership_id SERIAL PRIMARY KEY,
    university_id INTEGER REFERENCES universities(university_id),
    partner_university VARCHAR(255),
    country_code VARCHAR(3) REFERENCES countries(country_code),
    agreement_type VARCHAR(100),
    start_date DATE,
    end_date DATE,
    agreement_number VARCHAR(100) UNIQUE
);

-- УРОВЕНЬ 7: ТАБЛИЦЫ, ЗАВИСЯЩИЕ ОТ МНОГИХ ДРУГИХ
CREATE TABLE schedules (
    schedule_id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES courses(course_id),
    professor_id INTEGER REFERENCES professors(professor_id),
    group_id INTEGER REFERENCES student_groups(group_id),
    classroom_id INTEGER REFERENCES classrooms(classroom_id),
    day_of_week INTEGER REFERENCES week_days(day_code),
    start_time TIME,
    end_time TIME,
    schedule_type VARCHAR(20)
);

CREATE TABLE equipment_requests (
    request_id SERIAL PRIMARY KEY,
    department_id INTEGER REFERENCES departments(department_id),
    professor_id INTEGER REFERENCES professors(professor_id),
    equipment_name VARCHAR(255),
    equipment_type VARCHAR(10) REFERENCES equipment_types(equipment_code),
    quantity INTEGER,
    budget DECIMAL(10,2),
    request_date DATE,
    status VARCHAR(50) DEFAULT 'pending',
    priority INTEGER DEFAULT 1
);

CREATE TABLE university_events (
    event_id SERIAL PRIMARY KEY,
    faculty_id INTEGER REFERENCES faculties(faculty_id),
    name VARCHAR(255) NOT NULL,
    event_date DATE,
    event_type_code VARCHAR(10) REFERENCES event_types(event_type_code),
    participants_count INTEGER,
    budget DECIMAL(10,2),
    location VARCHAR(255)
);

-- УРОВЕНЬ 8: ТАБЛИЦЫ С САМЫМИ СЛОЖНЫМИ ЗАВИСИМОСТЯМИ
CREATE TABLE student_exchange_programs (
    exchange_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id),
    partnership_id INTEGER NOT NULL REFERENCES international_partnerships(partnership_id),
    semester_id INTEGER NOT NULL REFERENCES semesters(semester_id),
    destination_university VARCHAR(255),
    courses_taken TEXT,
    credits_transferred INTEGER,
    UNIQUE(student_id, partnership_id, semester_id)
);


-- УРОВЕНЬ 9: ДОБАВЛЕНИЕ ОТСУТСТВУЮЩИХ ВНЕШНИХ КЛЮЧЕЙ
ALTER TABLE faculties ADD CONSTRAINT fk_faculties_university
    FOREIGN KEY (university_id) REFERENCES universities(university_id);

ALTER TABLE departments ADD CONSTRAINT fk_departments_faculty
    FOREIGN KEY (faculty_id) REFERENCES faculties(faculty_id);
