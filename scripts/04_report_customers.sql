/*
---------------------------------------------------------------------------------------------------
CUSTOMER REPORT 
---------------------------------------------------------------------------------------------------
 
Purpose:
       This report consolidates cutomers metrics and behaviours

Highlights: 
        1. Gathers essential fields such as names, ages and transaction details
        2. Segments customers into categories (VIP, Regular, New) and age groups 
        3. Aggregates customer level metrics: 
           - total orders
           - total sales
           - total quantity purchased
           - total products 
           - lifespan(in months)
        4. Calculates valuable KPIs:
           - recency(months since last order)
           - average order value
           - average monthly spending                                                                                                                  */


CREATE VIEW gold.report_customers AS 

WITH base_query AS (
--1. retrieve core columns from both tables (Base Query)
SELECT 
    fs.order_number,
    fs.product_key,
    fs.order_date,
    fs.sales_amount,
    fs.quantity,
    dc.customer_key,
    dc.customer_number,
    CONCAT(dc.first_name,' ',  dc.last_name) customer_name,
    DATEDIFF(year, dc.birth_date, GETDATE()) age
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
WHERE order_date IS NOT NULL)

,

customer_aggregation AS (
--summarize key metrics at the customer level
SELECT 
    customer_key,
    customer_number,
    customer_name,
    age,
    MAX(order_date) last_order_date,
    COUNT(DISTINCT order_number) total_orders,
    SUM(sales_amount) total_sales,
    SUM(quantity) total_quantity,
    COUNT(DISTINCT product_key) total_products,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) lifespan 
FROM base_query
GROUP BY customer_key,
    customer_number,
    customer_name,
    age
)




SELECT *,
    CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
	     WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
	     ELSE 'New' END AS customer_status,
    CASE WHEN age < 20 THEN 'Below 20'
         WHEN age BETWEEN 20 AND 29 THEN '20-29'
         WHEN age BETWEEN 30 AND 39 THEN '30-39'
         WHEN age BETWEEN 40 AND 50 THEN '40-50'
         ELSE 'Above 50' END AS age_status,
    DATEDIFF(month, last_order_date, GETDATE()) recency,
    --average order value(AOV)
    CASE 
        WHEN total_orders = 0 OR total_sales = 0 THEN 0 
        ELSE total_sales / total_orders END AS avg_order_value,
    --average monthly spending
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan END AS avg_monthly_spending
FROM customer_aggregation




