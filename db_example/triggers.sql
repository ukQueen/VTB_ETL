-- Проверка оценки на допустимый диапазон
CREATE OR REPLACE FUNCTION check_grade_range()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.grade_value < 2.0 OR NEW.grade_value > 5.0 THEN
        RAISE EXCEPTION 'Оценка должна быть в диапазоне от 2.0 до 5.0';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER grade_range_trigger
    BEFORE INSERT OR UPDATE ON grades
    FOR EACH ROW EXECUTE FUNCTION check_grade_range();

-- Проверка дат (начало раньше конца)
CREATE OR REPLACE FUNCTION check_dates_validity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_date > NEW.end_date THEN
        RAISE EXCEPTION 'Дата начала не может быть позже даты окончания';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER research_projects_dates_trigger
    BEFORE INSERT OR UPDATE ON research_projects
    FOR EACH ROW EXECUTE FUNCTION check_dates_validity();

CREATE TRIGGER scholarships_dates_trigger
    BEFORE INSERT OR UPDATE ON scholarships
    FOR EACH ROW EXECUTE FUNCTION check_dates_validity();

CREATE TRIGGER international_partnerships_dates_trigger
    BEFORE INSERT OR UPDATE ON international_partnerships
    FOR EACH ROW EXECUTE FUNCTION check_dates_validity();