

This project represents the next step in my data journey, building directly upon the **SQL Data Warehouse Project** I completed previously. You can explore the foundation of this work here: [sql-data-warehouse-project](https://github.com/kevkaleido/sql-data-warehouse-project).

My goal was to take the structured data in my warehouse and perform a full analytics lifecycle—from initial exploration to building comprehensive reports—to uncover actionable business insights.

## The Foundation

I began by building the infrastructure for analysis. I created a database called DataWarehouseAnalytics with a gold schema containing three essential tables: `gold.dim_customers`, `gold.dim_products`, and `gold.fact_sales`. These tables were populated through bulk inserts from CSV datasets, establishing the foundation for all subsequent analysis.

During this initial setup, I learned a fundamental concept that would guide my entire approach: the distinction between dimensions and measures. Simply put, if a column is numeric and can be aggregated, it's a measure; otherwise, it's a dimension. This understanding became crucial for every analytical decision that followed.

## Exploring the Data Landscape

Before diving into analysis, I needed to understand what I was working with. I began by exploring the database structure using `INFORMATION_SCHEMA.TABLES` to view all metadata, including database names, schemas, table names, and types. Similarly, `INFORMATION_SCHEMA.COLUMNS` revealed the metadata for all columns, allowing me to filter for specific tables when needed.

My exploration of dimensions revealed the categorical nature of the data. Using `DISTINCT` queries, I discovered all the countries our customers came from and identified product categories representing the major business divisions. This gave me a clear picture of the data's geographical and categorical scope.

Understanding the temporal boundaries was equally important. Through `MIN` and `MAX` functions on date dimensions, I identified the earliest and latest order dates, calculated the years of sales data available, and even found our youngest and oldest customers. This temporal mapping provided essential context for all time-based analyses.

## Measuring Success

The exploration of measures required a more nuanced approach. I learned an important lesson early on: when counting orders, using `COUNT(order_number)` includes duplicates, which inflates the count since multiple items can belong to one order. The correct approach is `COUNT(DISTINCT order_number)` to get accurate order counts.

Through systematic aggregation, I established key business metrics: total sales, items sold, average selling price, total orders, and counts of products and customers. I also distinguished between total customers and customers who had actually placed orders, providing insight into customer activation rates.

## Comparative Analysis

The next phase involved comparing measure values across categories using the pattern `SUM[measure] BY [dimension]`. I discovered that when working with multiple tables, starting with the fact table and left joining dimension tables yields the most reliable results.

This approach revealed customer distributions by country and gender, product counts by category, average costs across categories, revenue generation by category and customer, and the distribution of sold items across different geographical regions. Each insight built upon the previous ones, creating a comprehensive picture of business performance.

## Ranking and Performance

To identify top and bottom performers, I employed ranking functions alongside the `SELECT TOP` clause. This analysis revealed our five highest revenue-generating products and the five worst performers, similar insights for subcategories, customers with the fewest orders, and our top 10 revenue-generating customers.

## Advanced Analytics: Time and Trends

The advanced analytics phase focused on understanding how performance changed over time. By aggregating measures by date dimensions (`SUM[measure] BY [Date Dimension]`), I could analyze sales performance trends exclusively within fact tables.

Cumulative analysis became particularly valuable for understanding business growth or decline. I calculated monthly sales totals, running totals over time, and moving average prices. These progressive aggregations revealed whether the business was trending upward or facing challenges.

## Performance Benchmarking

Performance analysis required comparing current values to targets using the formula `current[Measure] - target[measure]`. I focused on yearly product performance, which required understanding that I needed order_date dimensions, product_name dimensions, and sales_amount measures spanning two tables.

Following best practices, I started with the sales details table (containing measures) and left joined the product info table (containing dimensions). I converted order_date to years and summed sales amounts, grouping by year and product name to create a yearly performance baseline.

Using a CTE called `yearly_product_performance`, I employed window functions to calculate average sales performance for each product (`AVG` partitioned by `product_name`). This enabled comparisons between current sales and average performance, with case statements flagging results as above average, below average, or average.

For year-over-year analysis, I used the `LAG` function to access previous year sales: `LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year ASC)`. This allowed me to identify sales increases, decreases, or stagnation compared to the previous year.

## Proportional Analysis

Understanding part-to-whole relationships required calculating `([measure/total measure]) * 100 BY [dimension]`. When determining which categories contributed most to overall sales, I encountered a technical challenge: dividing one integer column by another always produces an integer, not a decimal.

The solution involved using `CAST` to convert one column to `FLOAT`, then applying `ROUND` to limit decimal places and concatenating a percentage symbol for clear presentation. This revealed each category's contribution to total sales with properly formatted percentages.

## Data Segmentation

Segmentation involved grouping data by specific ranges to understand correlations between measures. Using `CASE WHEN` statements, I could categorize continuous measures into discrete ranges, then apply aggregate functions grouped by these new categorical dimensions.

A particularly interesting challenge was segmenting customers into three spending behavior groups:
- **VIP**: At least 12 months of history and spending more than 5,000
- **Regular**: At least 12 months of history but spending 5,000 or less  
- **New**: Lifespan less than 12 months

This required calculating customer total spending (summed sales_amount), first and last order dates (using `MIN` and `MAX`), and customer lifespan (using `DATEDIFF` between first and last orders). A CTE called `customer_metrics` contained these calculations, followed by `CASE WHEN` statements for segmentation logic.

## Comprehensive Reporting

The final phase involved creating extensive customer and product reports following a structured three-step approach:

**Step 1 - Base Query**: Select necessary columns from dimension and fact tables, make required transformations, and convert to a CTE.

**Step 2 - Aggregation**: Aggregate required measures, selecting necessary columns from the base query CTE, then convert to another CTE.

**Step 3 - Final Result**: Create final results by selecting from previous CTEs and making final transformations.

### Customer Report

The customer report consolidated metrics and behaviors with these highlights:
- Essential fields including names, ages, and transaction details
- Customer segmentation into categories (VIP, Regular, New) and age groups
- Customer-level metrics: total orders, sales, quantity purchased, products, and lifespan in months
- Valuable KPIs: recency (months since last order), average order value, and average monthly spending

I concatenated first and last names into a single customer name column and converted birthdates to ages using `DATEDIFF`. The aggregation phase required careful attention to distinct counts—using `COUNT(DISTINCT order_number)` for total orders and `COUNT(DISTINCT product_key)` for total products to avoid duplicate inflation.

KPI calculations required special handling for division by zero scenarios. Average order value (total sales / total orders) and average monthly spending (total sales / lifespan in months) both needed `CASE WHEN` statements to handle zero denominators gracefully.

### Product Report

Following the same structured approach, the product report gathered essential fields like product name, category, subcategory, and cost, while segmenting products by revenue performance (High-Performers, Mid-Range, Low-Performers).

Product-level metrics included total orders, sales, quantity sold, unique customers, lifespan in months, and average selling price. An important distinction emerged: `COUNT(customer_key)` counts all transactions, while `COUNT(DISTINCT customer_key)` counts unique customers—a critical difference for accurate customer metrics.

Average selling price calculation used `AVG(sales_amount / quantity)` to provide meaningful per-unit pricing insights.

Both reports were saved as views (`gold.report_customers` and `gold.report_products`) for easy access and future analysis.

## Key Learnings

This project reinforced several critical principles:
- Always start with fact tables when joining multiple tables
- Use `DISTINCT` counts carefully to avoid inflated metrics  
- Handle division by zero scenarios proactively
- Convert data types appropriately for decimal calculations
- Structure complex analyses using CTEs for clarity and maintainability
- Design reports with clear business objectives and KPIs
