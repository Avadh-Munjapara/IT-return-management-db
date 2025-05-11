CREATE TABLE Teacher
(
  teacher_id INT NOT NULL,
  f_name VARCHAR(30) NOT NULL,
  l_name VARCHAR(30) NOT NULL,
  m_name VARCHAR(30) NOT NULL,
  joining_date DATE NOT NULL,
  contact_no bigint NOT NULL,
  h_no VARCHAR(15) NOT NULL,
  street VARCHAR(30) NOT NULL,
  pin_code INT NOT NULL,
  PRIMARY KEY (teacher_id),
  UNIQUE (contact_no)
);

CREATE TABLE dependent_child
(
  teacher_id INT NOT NULL,
  dependent_id INT NOT NULL,
  f_name VARCHAR(30) NOT NULL,
  l_name VARCHAR(30) NOT NULL,
  m_name VARCHAR(30) NOT NULL,
  edu_expense INT NOT NULL,
  dob DATE NOT NULL,
  age INT NOT NULL,
  PRIMARY KEY (teacher_id,dependent_id),
  FOREIGN KEY (teacher_id) REFERENCES Teacher(teacher_id)
);

CREATE TABLE annual_income
(
  teacher_id INT NOT NULL,
  income_id INT NOT NULL,
  medical_al INT NOT NULL,
  house_rent_al INT NOT NULL,
  other_al INT NOT NULL,
  basic_salary INT NOT NULL,
  other_income INT NOT NULL,
  gross_salary INT,
  gross_total_income INT, 
  PRIMARY KEY (income_id),
  FOREIGN KEY (teacher_id) REFERENCES Teacher(teacher_id)
);

CREATE TABLE sal_deduction
(
  teacher_id INT NOT NULL,
  income_id INT NOT NULL,
  s_d_id INT NOT NULL,
  g_p_f INT,
  proffessional_tax INT NOT NULL,
  std_deduction INT,
  total_deduction INT,
  PRIMARY KEY (s_d_id),
  FOREIGN KEY (income_id) REFERENCES annual_income(income_id),
  FOREIGN KEY (teacher_id) REFERENCES Teacher(teacher_id)
);

CREATE TABLE deductions
(
  teacher_id INT NOT NULL,
  deduction_id INT NOT NULL,
  amount INT NOT NULL,
  sec_no VARCHAR(5) NOT NULL,
  name VARCHAR(30) NOT NULL,
  PRIMARY KEY (teacher_id,deduction_id),
  FOREIGN KEY (teacher_id) REFERENCES Teacher(teacher_id)
);

CREATE TABLE tax
(
  teacher_id INT NOT NULL,
  income_id INT NOT NULL,
  tax_id INT NOT NULL,
  net_income INT,
  tax_on_income INT,
  health_edu_cess INT,
  total_tax INT,
  PRIMARY KEY (tax_id),
  FOREIGN KEY (income_id) REFERENCES annual_income(income_id),
  FOREIGN KEY (teacher_id) REFERENCES Teacher(teacher_id)
);





--trigger to calculate and set gross salary and gross total income of teacher while inserting data to table annual_incomme.

CREATE OR REPLACE FUNCTION calc_gincome()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
	update annual_income set gross_salary=new.medical_al+new.house_rent_al+new.other_al+new.basic_salary
	where teacher_id=new.teacher_id;
    update annual_income set gross_total_income=gross_salary+new.other_income
	where teacher_id=new.teacher_id;
	RETURN NEW;
END;
$$

CREATE TRIGGER calc_gincome after insert ON  annual_income FOR EACH ROW EXECUTE PROCEDURE calc_gincome();
  
 
 
--trigger to calculate and set g.p.f,standard deduction and total dedution while inserting data to table sal_deduction.
 
CREATE OR REPLACE FUNCTION calc_total_sdeduction()
RETURNS TRIGGER AS $$
declare b_s int;
BEGIN
select basic_salary into b_s from annual_income where teacher_id=new.teacher_id;
update sal_deduction set g_p_f= 0.12 * b_s where teacher_id=new.teacher_id;
update sal_deduction set std_deduction = 50000 where teacher_id=new.teacher_id;
update sal_deduction
   set total_deduction = g_p_f + new.proffessional_tax + std_deduction
	where teacher_id=new.teacher_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

create trigger calc_total_sdeduction after insert on sal_deduction for each row EXECUTE PROCEDURE calc_total_sdeduction();

drop trigger calc_total_sdeduction on sal_deduction;

--trigger to calulate sum of education expenses of dependent childs,sum of all deduction amount 
-- of a teacher and calculate and set net income , tax on incomme , health and education cess and total tax while inserting to table tax.

CREATE OR REPLACE FUNCTION calculate_tax()
    RETURNS TRIGGER AS $$
DECLARE
    p_income INT;           
	de_edu int;
	t_deduction int;
	
BEGIN
     select sum(edu_expense) into de_edu  from dependent_child where teacher_id=new.teacher_id;
	 if de_edu > 150000 then de_edu := 150000;
	 end if;
	 select sum(amount)into t_deduction from deductions where teacher_id=new.teacher_id;
    UPDATE tax
    SET net_income = (
        SELECT ai.gross_total_income - sd.total_deduction
        FROM annual_income ai
        JOIN sal_deduction sd ON ai.income_id = sd.income_id
		WHERE ai.teacher_id = NEW.teacher_id
    ) - de_edu - t_deduction
    WHERE tax.teacher_id = NEW.teacher_id;

    SELECT net_income FROM tax WHERE teacher_id = NEW.teacher_id INTO p_income;
	
IF p_income < 300000 THEN
    UPDATE tax 
    SET tax_on_income = 0, health_edu_cess = 0
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 300000 AND p_income < 600000 THEN
    UPDATE tax 
    SET tax_on_income = p_income * 0.05
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 600000 AND p_income < 900000 THEN
    UPDATE tax 
    SET tax_on_income = 15000 + (p_income - 600000) * 0.10
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 900000  AND p_income < 1200000 THEN
    UPDATE tax 
    SET tax_on_income = 45000 + (p_income - 900000) * 0.15
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 1200000 AND p_income < 1500000 THEN
    UPDATE tax 
    SET tax_on_income = 90000 + (p_income - 1200000) * 0.20
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 1500000 THEN
    UPDATE tax 
    SET tax_on_income = 150000 + (p_income - 1500000) * 0.30
    WHERE teacher_id = NEW.teacher_id;
END IF;

UPDATE tax SET health_edu_cess = 0.04 * tax_on_income WHERE teacher_id = NEW.teacher_id;

UPDATE tax SET total_tax = tax_on_income + health_edu_cess WHERE teacher_id = NEW.teacher_id;

    RETURN NEW;
	
END;

$$ LANGUAGE plpgsql;


create trigger calculate_tax after insert on  tax for each row EXECUTE PROCEDURE calculate_tax();

drop trigger calculate_tax on tax;



---Trigger to update total deduction

CREATE OR REPLACE FUNCTION update_total_deduction()
  RETURNS TRIGGER 
AS
$$
BEGIN
  UPDATE sal_deduction
  SET
    total_deduction = g_p_f+ NEW.proffessional_tax + std_deduction
  WHERE teacher_id = NEW.teacher_id;

  RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;


CREATE TRIGGER update_total_deduction
AFTER update ON sal_deduction
FOR EACH ROW
EXECUTE FUNCTION update_total_deduction();

drop trigger update_total_deduction ON sal_deduction;

--- Trigger to update tax details

CREATE OR REPLACE FUNCTION recalculate_tax_details()
  RETURNS TRIGGER 
AS
$$
DECLARE
    p_income INT;
	de_edu int;
	t_deduction int;
	
BEGIN
 select sum(edu_expense) into de_edu  from dependent_child where teacher_id=new.teacher_id;
	 if de_edu > 150000 then de_edu := 150000;
	 end if;
	 select sum(amount)into t_deduction from deductions where teacher_id=new.teacher_id;
    UPDATE tax
    SET net_income = (
        SELECT ai.gross_total_income - sd.total_deduction
        FROM annual_income ai
        JOIN sal_deduction sd ON ai.income_id = sd.income_id
		WHERE ai.teacher_id = NEW.teacher_id
    ) - de_edu - t_deduction
    WHERE tax.teacher_id = NEW.teacher_id;

    SELECT net_income FROM tax WHERE teacher_id = NEW.teacher_id INTO p_income;
	
IF p_income < 300000 THEN
    UPDATE tax 
    SET tax_on_income = 0, health_edu_cess = 0
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 300000 AND p_income < 600000 THEN
    UPDATE tax 
    SET tax_on_income = p_income * 0.05
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 600000 AND p_income < 900000 THEN
    UPDATE tax 
    SET tax_on_income = 15000 + (p_income - 600000) * 0.10
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 900000  AND p_income < 1200000 THEN
    UPDATE tax 
    SET tax_on_income = 45000 + (p_income - 900000) * 0.15
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 1200000 AND p_income < 1500000 THEN
    UPDATE tax 
    SET tax_on_income = 90000 + (p_income - 1200000) * 0.20
    WHERE teacher_id = NEW.teacher_id;

ELSIF p_income >= 1500000 THEN
    UPDATE tax 
    SET tax_on_income = 150000 + (p_income - 1500000) * 0.30
    WHERE teacher_id = NEW.teacher_id;
END IF;

UPDATE tax SET health_edu_cess = 0.04 * tax_on_income WHERE teacher_id = NEW.teacher_id;

UPDATE tax SET total_tax = tax_on_income + health_edu_cess WHERE teacher_id = NEW.teacher_id;

  RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;



CREATE TRIGGER recalculate_tax_details
AFTER UPDATE ON sal_deduction
FOR EACH ROW
EXECUTE FUNCTION recalculate_tax_details();

drop trigger recalculate_tax_details ON tax;


-----Insert Queries

INSERT INTO Teacher (teacher_id, f_name, l_name, m_name, joining_date, contact_no, h_no, street, pin_code)
VALUES (1, 'Rajesh', 'Kumar', 'S', '2023-01-01', 9876543210, 'A1', 'Gandhi Nagar', 110001);

INSERT INTO Teacher (teacher_id, f_name, l_name, m_name, joining_date, contact_no, h_no, street, pin_code)
VALUES (2, 'Priya', 'Sharma', 'K', '2023-01-01', 9876543211, 'B2', 'Jawahar Road', 201301);

INSERT INTO Teacher (teacher_id, f_name, l_name, m_name, joining_date, contact_no, h_no, street, pin_code)
VALUES (3, 'Amit', 'Patel', 'R', '2023-01-01', 9876543212, 'C3', 'Vivekananda Lane', 400001);

INSERT INTO Teacher (teacher_id, f_name, l_name, m_name, joining_date, contact_no, h_no, street, pin_code)
VALUES (4, 'Neha', 'Verma', 'B', '2023-01-01', 9876543213, 'D4', 'Tagore Street', 600001);

INSERT INTO Teacher (teacher_id, f_name, l_name, m_name, joining_date, contact_no, h_no, street, pin_code)
VALUES (5, 'Anil', 'Yadav', 'M', '2023-01-01', 9876543214, 'E5', 'Lal Bahadur Road', 500001);





INSERT INTO dependent_child (teacher_id, dependent_id, f_name, l_name, m_name, edu_expense, dob, age)
VALUES (1, 1, 'Aarav', 'Kumar', 'Rajesh', 50000, '2010-01-15', 12);
    
INSERT INTO dependent_child (teacher_id, dependent_id, f_name, l_name, m_name, edu_expense, dob, age)
VALUES (2, 2, 'Advait', 'Sharma', 'Priya', 55000, '2011-02-10', 11),
       (2, 3, 'Anaya', 'Sharma', 'Priya', 100000, '2013-07-25', 9);

INSERT INTO dependent_child (teacher_id, dependent_id, f_name, l_name, m_name, edu_expense, dob, age)
VALUES (3, 4, 'Arjun', 'Patel', 'Amit', 45000, '2012-03-05', 10);

INSERT INTO dependent_child (teacher_id, dependent_id, f_name, l_name, m_name, edu_expense, dob, age)
VALUES (4,5 , 'Aditya', 'Verma', 'Neha', 48000, '2010-11-20', 15);

INSERT INTO dependent_child (teacher_id, dependent_id, f_name, l_name, m_name, edu_expense, dob, age)
VALUES (4,6 , 'Aryan', 'Verma', 'Neha', 38000, '2009-11-20', 13);

INSERT INTO dependent_child (teacher_id, dependent_id, f_name, l_name, m_name, edu_expense, dob, age)
VALUES (5, 7, 'Aarush', 'Yadav', 'Anil', 53000, '2010-06-12', 12);
  







INSERT INTO annual_income (teacher_id, income_id, medical_al, house_rent_al, other_al, basic_salary, other_income)
VALUES (1, 1, 15000, 12000, 5000, 980000, 10000);

INSERT INTO annual_income (teacher_id, income_id, medical_al, house_rent_al, other_al, basic_salary, other_income)
VALUES (2, 2, 12000, 10000, 4000, 1220000, 8000);

INSERT INTO annual_income (teacher_id, income_id, medical_al, house_rent_al, other_al, basic_salary, other_income)
VALUES (3, 3, 18000, 15000, 6000, 390000, 12000);

INSERT INTO annual_income (teacher_id, income_id, medical_al, house_rent_al, other_al, basic_salary, other_income)
VALUES (4, 4, 14000, 11000, 4500, 820000, 9000);

INSERT INTO annual_income (teacher_id, income_id, medical_al, house_rent_al, other_al, basic_salary, other_income)
VALUES (5, 5, 16000, 13000, 5500, 650000, 11000);






INSERT INTO sal_deduction (teacher_id, income_id, s_d_id, proffessional_tax)
VALUES (1, 1, 1, 2000);

INSERT INTO sal_deduction (teacher_id, income_id, s_d_id, proffessional_tax)
VALUES (2, 2, 2, 1800);

INSERT INTO sal_deduction (teacher_id, income_id, s_d_id, proffessional_tax)
VALUES (3, 3, 3, 2200);

INSERT INTO sal_deduction (teacher_id, income_id, s_d_id, proffessional_tax)
VALUES (4, 4, 4, 1900);

INSERT INTO sal_deduction (teacher_id, income_id, s_d_id, proffessional_tax)
VALUES (5, 5, 5, 2100);






INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (1, 1, 5000, '80C', 'Provident Fund');

INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (2, 2, 6000, '80D', 'Medical Insurance');

INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (2, 3, 5000, '80E', 'Education Loan Interest');

INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (3, 4, 4500, '24B', 'House Rent Allowance');

INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (4, 5, 5500, '80G', 'Charitable Donations');

INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (4, 6,4500, '80D', 'Medical Insurance');

INSERT INTO deductions (teacher_id, deduction_id, amount, sec_no, name)
VALUES (5, 7, 5000, '80E', 'Education Loan Interest');







INSERT INTO tax (teacher_id, income_id, tax_id)
VALUES (1, 1, 1);

INSERT INTO tax (teacher_id, income_id, tax_id)
VALUES (2, 2, 2);

INSERT INTO tax (teacher_id, income_id, tax_id)
VALUES (3, 3, 3);

INSERT INTO tax (teacher_id, income_id, tax_id)
VALUES (4, 4, 4);

INSERT INTO tax (teacher_id, income_id, tax_id)
VALUES (5, 5, 5);



---- Cursors

DO $$ 
DECLARE 
    teacher_rec Teacher%ROWTYPE;
    teacher_cursor CURSOR FOR SELECT * FROM Teacher;
BEGIN
    OPEN teacher_cursor;
    LOOP
        FETCH teacher_cursor INTO teacher_rec;
        EXIT WHEN NOT FOUND;
        -- Process the teacher record as needed
        RAISE NOTICE 'Teacher: % % %', teacher_rec.f_name, teacher_rec.l_name, teacher_rec.contact_no;
    END LOOP;
    CLOSE teacher_cursor;
END $$;






DO $$ 
DECLARE 
    teacher_rec Teacher%ROWTYPE;
    teacher_cursor CURSOR FOR 
        SELECT * 
        FROM Teacher 
        WHERE teacher_id IN (SELECT teacher_id FROM dependent_child WHERE edu_expense > 80000);
BEGIN
    OPEN teacher_cursor;
    LOOP
        FETCH teacher_cursor INTO teacher_rec;
        EXIT WHEN NOT FOUND;
        -- Process teachers with high education expenses as needed
        RAISE NOTICE 'High Edu Expense Teacher: % %', teacher_rec.f_name, teacher_rec.l_name;
    END LOOP;
    CLOSE teacher_cursor;
END $$;







DO $$ 
DECLARE 
    teacher_rec Teacher%ROWTYPE;
    teacher_cursor CURSOR FOR 
        SELECT * 
        FROM Teacher 
        WHERE teacher_id IN (SELECT teacher_id FROM tax WHERE total_tax > 50000);
BEGIN
    OPEN teacher_cursor;
    LOOP
        FETCH teacher_cursor INTO teacher_rec;
        EXIT WHEN NOT FOUND;
        -- Process teachers with high tax liabilities as needed
        RAISE NOTICE 'High Tax Teacher: % %', teacher_rec.f_name, teacher_rec.l_name;
    END LOOP;
    CLOSE teacher_cursor;
END $$;









DO $$ 
DECLARE 
    teacher_rec Teacher%ROWTYPE;
    teacher_cursor CURSOR FOR 
        SELECT * FROM Teacher WHERE EXTRACT(YEAR FROM AGE(NOW(), joining_date)) BETWEEN 25 AND 35;
BEGIN
    OPEN teacher_cursor;
    LOOP
        FETCH teacher_cursor INTO teacher_rec;
        EXIT WHEN NOT FOUND;
        -- Process teachers with age between 25 and 35 as needed
        RAISE NOTICE 'Age Between 25 and 35 Teacher: % %', teacher_rec.f_name, teacher_rec.l_name;
    END LOOP;
    CLOSE teacher_cursor;
END $$;









DO $$ 
DECLARE 
    teacher_rec Teacher%ROWTYPE;
    teacher_cursor CURSOR FOR SELECT * FROM Teacher;
BEGIN
    OPEN teacher_cursor;
    LOOP
        FETCH teacher_cursor INTO teacher_rec;
        EXIT WHEN NOT FOUND;
        -- Update other allowances for teachers as needed
        UPDATE annual_income 
        SET medical_al = medical_al * 1.05,
            house_rent_al = house_rent_al * 1.1,
            other_al = other_al * 1.08
        WHERE teacher_id = teacher_rec.teacher_id;
    END LOOP;
    CLOSE teacher_cursor;
END $$;


-----Procedures

CREATE OR REPLACE PROCEDURE insert_teacher(
    in_teacher_id INT,
    in_f_name VARCHAR(30),
    in_l_name VARCHAR(30),
    in_m_name VARCHAR(30),
    in_joining_date DATE,
    in_contact_no BIGINT,
    in_h_no VARCHAR(15),
    in_street VARCHAR(30),
    in_pin_code INT
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    INSERT INTO Teacher (
        teacher_id, f_name, l_name, m_name, joining_date,
        contact_no, h_no, street, pin_code
    ) VALUES (
        in_teacher_id, in_f_name, in_l_name, in_m_name, in_joining_date,
        in_contact_no, in_h_no, in_street, in_pin_code
    );
END;
$$;





CREATE OR REPLACE PROCEDURE update_teacher(
    in_teacher_id INT,
    in_f_name VARCHAR(30),
    in_l_name VARCHAR(30),
    in_m_name VARCHAR(30),
    in_joining_date DATE,
    in_contact_no BIGINT,
    in_h_no VARCHAR(15),
    in_street VARCHAR(30),
    in_pin_code INT
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    UPDATE Teacher
    SET
        f_name = in_f_name,
        l_name = in_l_name,
        m_name = in_m_name,
        joining_date = in_joining_date,
        contact_no = in_contact_no,
        h_no = in_h_no,
        street = in_street,
        pin_code = in_pin_code
    WHERE teacher_id = in_teacher_id;
END;
$$;






CREATE OR REPLACE PROCEDURE insert_dependent_child(
    in_teacher_id INT,
    in_dependent_id INT,
    in_f_name VARCHAR(30),
    in_l_name VARCHAR(30),
    in_m_name VARCHAR(30),
    in_edu_expense INT,
    in_dob DATE,
    in_age INT
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    INSERT INTO dependent_child (
        teacher_id, dependent_id, f_name, l_name, m_name,
        edu_expense, dob, age
    ) VALUES (
        in_teacher_id, in_dependent_id, in_f_name, in_l_name, in_m_name,
        in_edu_expense, in_dob, in_age
    );
END;
$$;






CREATE OR REPLACE PROCEDURE calculate_gross_income(
    in_teacher_id INT,
    in_income_id INT,
    in_medical_al INT,
    in_house_rent_al INT,
    in_other_al INT,
    in_basic_salary INT,
    in_other_income INT
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    UPDATE annual_income
    SET
        gross_salary = in_medical_al + in_house_rent_al + in_other_al + in_basic_salary,
        gross_total_income = in_medical_al + in_house_rent_al + in_other_al + in_basic_salary + in_other_income
    WHERE teacher_id = in_teacher_id AND income_id = in_income_id;
END;
$$;






CREATE OR REPLACE PROCEDURE insert_salary_deduction(
    in_teacher_id INT,
    in_income_id INT,
    in_s_d_id INT,
    in_g_p_f INT,
    in_professional_tax INT,
    in_std_deduction INT,
    in_total_deduction INT
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    INSERT INTO sal_deduction (
        teacher_id, income_id, s_d_id, g_p_f, proffessional_tax, std_deduction, total_deduction
    ) VALUES (
        in_teacher_id, in_income_id, in_s_d_id, in_g_p_f, in_professional_tax, in_std_deduction, in_total_deduction
    );
END;
$$;








