/*
===============================================================================
ADVANCED TIME SERIES & PERFORMANCE ANALYTICS
===============================================================================

Purpose: Dive deeper into sales patterns over time, compare performance across periods,
         and group customers based on their buying behavior.

What this script does:
- Tracks sales performance by year, month, and day of the week
- Creates running totals to see cumulative sales growth over time
- Compares each product's current year sales to previous years and averages
- Calculates what percentage each product category contributes to total sales
- Groups products into price ranges (cheap, mid-range, expensive)
- Segments customers into VIP, Regular, and New based on spending and loyalty
- Identifies trends like "sales increasing" or "performance above average"

Key Functions Used:
- DATETRUNC, DATENAME (group sales by time periods)
- Window functions with OVER (calculate running totals and moving averages)
- LAG (compare current year to previous year performance)
- PARTITION BY (calculate averages within each product group)
- CASE statements (create categories and status labels)
- CTE/WITH (break complex analysis into manageable steps)
- CAST, CONCAT (format percentages and text outputs)

Tables analyzed: Customer info, Product catalog, Sales transactions
===============================================================================                                                                               */





--analyze sales performance over time

--year
SELECT datename(year,order_date) year,
SUM(sales_amount) sales_performance
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY datename(year,order_date)
ORDER BY datename(year,order_date)

--month
SELECT 
datename(month,order_date) month,
SUM(sales_amount) sales_performance
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY datename(month,order_date)
ORDER BY sales_performance desc

--day
SELECT datename(weekday,order_date) day,
SUM(sales_amount) sales_performance
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY datename(weekday,order_date)
ORDER BY sales_performance desc





--calculate the total sales per month


SELECT 
	DATETRUNC(month, order_date) order_date,
	SUM(sales_amount) OVER (ORDER BY DATETRUNC(month, order_date)) total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date)



-- the running total of sales over time
SELECT *,
SUM(total_sales) OVER (ORDER BY order_date) running_total
FROM (
	SELECT 
		DATETRUNC(month, order_date) order_date,
		SUM(sales_amount) total_sales
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(month, order_date)
	)sub


--the running total of sales for each year

SELECT *,
SUM(total_sales) OVER ( ORDER BY order_date) running_total
FROM (
	SELECT 
		DATETRUNC(year, order_date) order_date,
		SUM(sales_amount) total_sales
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(year, order_date)
	)sub


--the moving average price
SELECT *,
SUM(total_sales) OVER(ORDER BY order_date) running_total,
SUM(average_price) OVER (ORDER BY order_date) running_average
FROM (
		SELECT 
		DATETRUNC(month, order_date) order_date,
		SUM(sales_amount) total_sales,
		AVG(price) average_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(month, order_date)
	)sub



--analyze the yearly performance of products by comparing each products sales to both its average sales performance and the previous years sales

WITH yearly_product_performance AS (
SELECT 
	YEAR(fs.order_date) order_year,
	dp.product_name,
	SUM(fs.sales_amount) current_sale
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(fs.order_date), dp.product_name )


SELECT 
	order_year,
	product_name,
	current_sale,
	AVG(current_sale) OVER (PARTITION BY product_name) avg_sale,
current_sale - AVG(current_sale) OVER (PARTITION BY product_name) avg_diff,
CASE WHEN current_sale - AVG(current_sale) OVER (PARTITION BY product_name) > 0
	 THEN 'Above Average'
	 WHEN current_sale - AVG(current_sale) OVER (PARTITION BY product_name) < 0
	 THEN 'Below Average' ELSE 'Average' END avg_status,
LAG(current_sale, 1, 0) OVER (PARTITION BY product_name ORDER BY order_year) previous_year_sales,
current_sale - LAG(current_sale, 1, 0) OVER (PARTITION BY product_name ORDER BY order_year) previous_year_sales_diff,
CASE WHEN current_sale - LAG(current_sale, 1, 0) OVER (PARTITION BY product_name ORDER BY order_year) > 0
     THEN 'Sale Increase'
	 WHEN current_sale - LAG(current_sale, 1, 0) OVER (PARTITION BY product_name ORDER BY order_year) < 0
	 THEN 'Sale Decrease'
	 ELSE 'No increase or decrease' END previous_year_sales_status
FROM yearly_product_performance
ORDER BY product_name, order_year





--which categories contribute the most to overall sales

SELECT
*,
SUM(category_sales) OVER() overall_sales,
CONCAT(ROUND((CAST(category_sales AS FLOAT) / SUM(category_sales) OVER()) * 100, 1), '%') category_contribution
	FROM(
	SELECT 
		dp.category,
		SUM(fs.sales_amount) category_sales
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_products dp
	ON fs.product_key = dp.product_key
	GROUP BY dp.category)sub
ORDER BY category_contribution DESC





--Segment products into cost ranges and count how many products fall into each segment


SELECT 
cost_range,
COUNT(product_name) no_of_products
	FROM(
	SELECT 
		product_name,
		cost,
		CASE WHEN cost < 100 THEN 'Below 100'
			 WHEN cost BETWEEN 100 AND 499 THEN '100 - 499'
			 WHEN cost BETWEEN 500 AND 1000 THEN '500 - 1000'
			 ELSE 'Above 1000' END cost_range
	FROM gold.dim_products)sub
GROUP BY cost_range
ORDER BY cost_range




/*
				Group customers into 3 segments based on their spending behaviour
				VIP: at least 12 months of history and spending more than 5000
				Regular: at least 12 months of history but spending 5000 or less
				New: lifespan less than 12 months     
				and find the total number of customers by each group                                      */


 WITH customer_metrics AS (
SELECT 
	dc.customer_key,
	dc.first_name,
	dc.last_name,
	SUM(fs.sales_amount) total_spending,
	MIN(order_date) first_order,
	MAX(order_date) last_order,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) life_span 
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_key,
	dc.first_name,
	dc.last_name)


SELECT customer_status,
	   COUNT(customer_key) customer_count
FROM(
SELECT *,
CASE WHEN life_span >= 12 AND total_spending > 5000 THEN 'VIP'
	 WHEN life_span >= 12 AND total_spending <= 5000 THEN 'Regular'
	 ELSE 'New' END customer_status
FROM customer_metrics)sub
GROUP BY customer_status
ORDER BY customer_count DESC




