-- After scanning through the table, there was an invalid date in the record which might mean wrong records
-- Deleting record
DELETE FROM loan_data
WHERE loan_id = '9190i0-nbfb' and borrower_id = '123fd36';



-- checking data types for loan_data table
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'loan_data';



-- Changing data type for interest rate column from time to float and maturity date from nvarchar to date
ALTER TABLE loan_data
ALTER COLUMN Maturity_date DATE;

-- changing for interest rate
--creating a new interest_rate column
ALTER TABLE loan_data
ADD Interest_Rate FLOAT;

-- Step 2
UPDATE loan_data
SET Interest_Rate = CAST(DATEPART(HOUR, InterestRate) AS FLOAT) + 0.01 * CAST(DATEPART(MINUTE, InterestRate) AS FLOAT);

-- Step 3
ALTER TABLE loan_data
DROP COLUMN InterestRate;




-- checking data types for borrower table
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'borrower';




-- checking data types for repayment table
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'repayment';

-- Observed column names amount paid and date paid are interchanged
-- Rename multiple columns in the loan_data table
EXEC sp_rename 'repayment.Amount_paid', 'Date_paid1', 'COLUMN';
EXEC sp_rename 'repayment.Date_paid', 'Amount_paid', 'COLUMN';
EXEC sp_rename 'repayment.Date_paid1', 'Date_paid', 'COLUMN';

-- Renaming the loan_id and payment_id and removing _pk and _fk
EXEC sp_rename 'repayment.loan_id_fk', 'loan_id', 'COLUMN';
EXEC sp_rename 'repayment.payment_id_pk', 'payment_id', 'COLUMN';



-- checking data types for schedule table
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'schedule';





-- Checking for duplicates in the borrower table
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY borrower_id ORDER BY borrower_id) AS Duplicate_count
FROM
    borrower;

-- Checking for duplicates in the loan data table
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY loan_id) AS Duplicate_count
FROM
    loan_data;


-- Checking for duplicates in the repayment table
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY payment_id ORDER BY loan_id) AS Duplicate_count
FROM
    repayment


-- Checking for duplicates in the schedule table
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY schedule_id ORDER BY loan_id) AS Duplicate_count
FROM
    schedule;


   

-- Calculating  PAR Days - Par Days and amount_at_risk
SELECT
    s.loan_id,
    s.Expected_payment_date,
    r.Date_paid,
    r.Amount_paid,
    s.expected_payment_amount,
	(s.Expected_payment_amount - r.amount_paid) AS outstanding,
    DATEDIFF(day, s.Expected_payment_date, r.Date_paid) AS PAR_Days,
    SUM(CASE
            WHEN DATEDIFF(day, s.Expected_payment_date, r.Date_paid) = 0 THEN DATEDIFF(day, s.Expected_payment_date, r.Date_paid)
			WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 0 THEN s.expected_payment_amount
            WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 1 THEN s.expected_payment_amount * 2
            WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 2 THEN s.expected_payment_amount * 3
            WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 3 THEN s.expected_payment_amount * 4
        END + (s.Expected_payment_amount - r.amount_paid)
    ) OVER (PARTITION BY s.Expected_payment_date ORDER BY s.loan_id, s.Expected_payment_date, r.Date_paid) AS amount_at_risk
FROM 
    Schedule s
LEFT JOIN 
    repayment r ON RIGHT(s.schedule_id, 5) = RIGHT(r.payment_id, 5)   
ORDER BY 
    s.loan_id, s.Expected_payment_date;


  

WITH temp
AS
	(SELECT
		s.loan_id,
		DATEDIFF(day, MAX(s.Expected_payment_date), GETDATE()) AS current_days_past_due,
		MAX(s.Expected_payment_date) AS last_due_date,
		MAX(r.Date_paid) AS last_repayment_date,
		SUM(r.Amount_paid) AS total_amount_paid,
		SUM(s.Expected_payment_amount) AS total_amount_expected
	FROM Schedule s
	LEFT JOIN 
		repayment r ON RIGHT(s.schedule_id, 5) = RIGHT(r.payment_id, 5)   
	GROUP BY s.loan_id
	),
temp1
AS
	(SELECT
		s.loan_id,
		s.Expected_payment_date,
		r.Date_paid,
		r.Amount_paid,
		s.expected_payment_amount,
		(s.Expected_payment_amount - r.amount_paid) AS outstanding,
		DATEDIFF(day, s.Expected_payment_date, r.Date_paid) AS PAR_Days,
		SUM(CASE
				WHEN DATEDIFF(day, s.Expected_payment_date, r.Date_paid) = 0 THEN DATEDIFF(day, s.Expected_payment_date, r.Date_paid)
				WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 0 THEN s.expected_payment_amount
				WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 1 THEN s.expected_payment_amount * 2
				WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 2 THEN s.expected_payment_amount * 3
				WHEN DATEDIFF(month, s.Expected_payment_date, r.Date_paid) = 3 THEN s.expected_payment_amount * 4
			END + (s.Expected_payment_amount - r.amount_paid)
		) OVER (PARTITION BY s.Expected_payment_date ORDER BY s.loan_id, s.Expected_payment_date, r.Date_paid) AS amount_at_risk
	FROM 
		Schedule s
	LEFT JOIN 
		repayment r ON RIGHT(s.schedule_id, 5) = RIGHT(r.payment_id, 5)   
	)


--branch,branch_id,borrower_name wasnt given in the 4 tables instead of 5 as the question stated
		SELECT
			l.loan_id,
			b.borrower_id,
			l.Date_of_release AS loan_date_of_release,
			l.term,
			l.LoanAmount,
			l.Downpayment,
			b.state,
			b.city,
			b.zip_code AS [zip code],
			l.payment_frequency,
			l.maturity_date,
			t.current_days_past_due,
			t.last_due_date,
			t.last_repayment_date,
			t1.amount_at_risk,
			b.borrower_credit_score,
			t.total_amount_paid,
			t.Total_amount_expected
		FROM
			Loan_data l
		JOIN
			Borrower b ON l.Borrower_id = b.Borrower_id
		JOIN
			temp t ON l.Loan_id = t.loan_id
		JOIN
			temp1 t1 ON l.loan_id = t1.loan_id
		ORDER BY l.loan_id, l.Borrower_id





