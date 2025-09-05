/*
---------------------------------------------------------------------------------------------------
PRODUCT REPORT 
---------------------------------------------------------------------------------------------------
 
Purpose:
       This report consolidates key product metrics and behaviours

Highlights: 
        1. Gathers essential fields such as product name, category, subcategory, and cost.
        2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
        3. Aggregates product level metrics: 
           - total orders
           - total sales
           - total quantity sold
           - total customers(unique) 
           - lifespan(in months)
        4. Calculates valuable KPIs:
           - recency(months since last order)
           - average order value
           - average monthly spending 
           - average selling price                                                                            */
       

CREATE VIEW gold.report_products AS

WITH base_query AS (
SELECT
--1. retrieve core columns from both tables (Base Query)
dp.product_key,
dp.product_name,
dp.category,
dp.subcategory,
dp.cost,
fs.order_number,
fs.order_date,
fs.sales_amount,
fs.customer_key,
fs.quantity
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key)

,
product_aggregation AS (
--summarize key metrics at the product level
SELECT 
product_key,
product_name,
category,
subcategory,
cost,
MAX(order_date) AS last_order_date,
--aggregations
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT customer_key) AS total_customers,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)) AS avg_selling_price
FROM base_query
GROUP BY 
    product_key,
    product_name,
    category,
    subcategory,
    cost)




SELECT *,
    CASE
         WHEN total_sales BETWEEN 2430 AND 459771 THEN 'Low Performers'
         WHEN total_sales BETWEEN 459772 AND 917113 THEN 'Mid-Range'
         ELSE 'High Revenue' END AS product_segment,
    DATEDIFF(month, last_order_date, GETDATE()) AS recency,
        --average order value(AOV)
    CASE 
         WHEN total_orders = 0 THEN 0
         ELSE total_sales / total_orders END AS avg_order_value,
        --average amount spent on product monthly
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan END AS avg_monthly_amount
FROM product_aggregation

