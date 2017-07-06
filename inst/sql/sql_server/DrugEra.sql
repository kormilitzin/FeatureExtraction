-- This file is automatically generated, do not edit by hand
-- Feature construction
{!@aggregated} ? {--HINT DISTRIBUTE_ON_KEY(row_id)}
SELECT 
	CAST(drug_concept_id AS BIGINT) * 1000 + @analysis_id AS covariate_id,
{@temporal} ? {
    time_id,
}	
{@aggregated} ? {
	COUNT(*) AS covariate_value
} : {
	cohort.@row_id_field AS row_id,
	1 AS covariate_value 
}
INTO @covariate_table
FROM @cohort_table cohort
INNER JOIN @cdm_database_schema.drug_era
	ON cohort.subject_id = drug_era.person_id
{@temporal} ? {
INNER JOIN #time_period
	ON drug_era_start_date <= DATEADD(DAY, time_period.end_day, cohort.cohort_start_date)
	AND drug_era_end_date >= DATEADD(DAY, time_period.start_day, cohort.cohort_start_date)
WHERE drug_concept_id != 0
} : {
WHERE drug_era_start_date < DATEADD(DAY, @end_day, cohort.cohort_start_date)
	AND drug_era_end_date >= DATEADD(DAY, @start_day, cohort.cohort_start_date)
	AND drug_concept_id != 0
}
{@has_excluded_covariate_concept_ids} ? {	AND drug_concept_id NOT IN (SELECT concept_id FROM #excluded_cov)}
{@has_included_covariate_concept_ids} ? {	AND drug_concept_id IN (SELECT concept_id FROM #included_cov)}
{@has_included_covariate_ids} ? {	AND CAST(drug_concept_id AS BIGINT) * 1000 + @analysis_id IN (SELECT concept_id FROM #included_cov_by_id)}
{@aggregated} ? {		
GROUP BY drug_concept_id
{@temporal} ? {
    ,time_id
}	
}
;

-- Reference construction
INSERT INTO #cov_ref (
	covariate_id,
	covariate_name,
	analysis_id,
	concept_id
	)
SELECT covariate_id,
{@temporal} ? {
	CONCAT('Drug era: ', concept_id, '-', concept_name) AS covariate_name,
} : {
	CONCAT('Drug era during day @start_day through @end_day days relative to index: ', concept_id, '-', concept_name) AS covariate_name,
}
	@analysis_id AS analysis_id,
	concept_id
FROM (
	SELECT DISTINCT covariate_id
	FROM @covariate_table
	) t1
INNER JOIN @cdm_database_schema.concept
	ON concept_id = CAST((covariate_id - @analysis_id) / 1000 AS INT);
