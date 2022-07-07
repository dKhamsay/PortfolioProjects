/* TMDB Movie Project
   Data From: https://www.kaggle.com/datasets/akshaypawar7/millions-of-movies?select=movies.csv
   Obtained On: 7/5/2022
*/



/*Section 1: Cleaning and Manipulating.
 My goal is to produce a table that I can use to do additional analysis on in Tableau.
 */
 
--Creating released movies table with desired columns
SELECT 
	title, 
	genres, 
	original_language,
	popularity,
	release_date, 
	budget, 
	revenue, 
	runtime, 
	status, 
	vote_average
INTO 
	#released_movies
FROM
	movies
WHERE 
	status = 'Released';

--Removing duplicates using CTE
WITH CTE( genres,
	original_language,
	release_date,
	budget,
	revenue,
	runtime,
	status, 
	vote_average,
	duplicate_count)
AS (SELECT genres,
	original_language,
	release_date,
	budget,
	revenue,
	runtime,
	status, 
	vote_average,
	ROW_NUMBER() OVER(PARTITION BY genres,
		original_language,
		release_date,
		budget,
		revenue,
		runtime,
		status, 
		vote_average
	ORDER BY title) AS duplicate_count
	FROM #released_movies)
DELETE FROM CTE
WHERE duplicate_count > 1;

--Removing rows with missing values or 0's
DELETE FROM #released_movies
WHERE COALESCE(title, genres) IS NULL
OR COALESCE(title, genres) = ' ';

DELETE FROM #released_movies
WHERE COALESCE(release_date, runtime) IS NULL;

DELETE FROM #released_movies
WHERE COALESCE(budget, revenue, runtime) = 0;

--Adding new columns to the released movies table
ALTER TABLE #released_movies
	ADD release_year INT,
		release_month VARCHAR(50),
		movie_length_type VARCHAR(50);

/*Updating columns
 -Capitalizing original language
 -Rounding vote and popularity
 -Splitting release date into year and month
 -Categorizing runtime
 */
UPDATE
	#released_movies
SET original_language = UPPER(original_language),
	vote_average = ROUND(vote_average,2),
	popularity = ROUND(popularity,2),
	release_year = YEAR(release_date),
	release_month = DATENAME(month, release_date),
	movie_length_type =
		    CASE WHEN runtime < 90 THEN 'Short'
            WHEN runtime > 150 THEN 'Long'
            ELSE 'Average' 
			END; 


/*SECTION 2: Analyzing Data
  Each query will have a comment about what information can be gathered.
*/
	
--Showing which movies are the most popular and their vote average
SELECT TOP(10)
	title, 
	popularity,
	vote_average
FROM #released_movies
ORDER BY popularity DESC;

--Showing which movies have the highest vote average of 10 
SELECT title, 
	   vote_average
FROM #released_movies
WHERE vote_average = 10;

--Showing popular movies by year
SELECT *
FROM (
	SELECT
	   title,
       release_year,
       RANK() OVER(PARTITION BY release_year ORDER BY popularity DESC) AS pop_rank
	FROM #released_movies) AS r
WHERE pop_rank = 1;

--Showing popular movies by genre
 SELECT r1.title, 
		r2.split_genres, 
		r2.max_pop
 FROM #released_movies r1
	INNER JOIN
	(SELECT value AS split_genres, 
		MAX(popularity) AS max_pop 
	FROM #released_movies 
    CROSS APPLY STRING_SPLIT(genres, '-')
GROUP BY value) r2 
	ON r1.popularity = r2.max_pop;

--Showing revenue by language
SELECT AVG(revenue) AS avg_revenue,
	   original_language
FROM #released_movies
GROUP BY original_language
ORDER BY avg_revenue DESC;

--Showing percent change in budget and revenue growth per year
SELECT release_year, 
       SUM(revenue) AS rev_per_year,
	   (SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY release_year ASC))/(LAG (SUM(revenue))  OVER (ORDER BY release_year ASC) * 100) AS rev_growth,
	   SUM(budget) AS budget_per_year,
	  (SUM(budget) - LAG(SUM(budget)) OVER (ORDER BY release_year ASC))/(LAG (SUM(budget))  OVER (ORDER BY release_year ASC) * 100) AS budget_growth,
	   COUNT(*) AS movies_released
FROM #released_movies
GROUP BY release_year
ORDER BY rev_growth DESC;

--Showing movies released by month
SELECT release_month,
	   COUNT(*) AS movie_totals
FROM #released_movies
GROUP BY release_month
ORDER BY movie_totals DESC;
