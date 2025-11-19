-- Question 3: ULTRA Plan Success Evaluation
-- Simple comparison: ULTRA vs Average of other plans with flag columns

WITH plan_metrics AS (
    -- Calculate all metrics by plan
    SELECT 
        u.plan,
        COUNT(DISTINCT u.user_id) AS total_users,
        COUNT(DISTINCT CASE WHEN u.created_date >= CURRENT_TIMESTAMP - INTERVAL 30 DAY THEN u.user_id END) AS new_users_30d,
        SUM(CASE WHEN t.state = 'completed' THEN t.amount_gbp ELSE 0 END) AS total_revenue_gbp,
        SUM(CASE WHEN t.state = 'completed' THEN t.amount_gbp ELSE 0 END) / NULLIF(COUNT(DISTINCT u.user_id), 0) AS revenue_per_user,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        COUNT(DISTINCT t.transaction_id) / NULLIF(COUNT(DISTINCT u.user_id), 0) AS transactions_per_user,
        COUNT(CASE WHEN t.state = 'completed' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS transaction_success_rate_pct,
        AVG(CASE WHEN t.state = 'completed' THEN t.amount_gbp END) AS avg_transaction_amount,
        COUNT(DISTINCT a.activity_id) * 1.0 / NULLIF(COUNT(DISTINCT u.user_id), 0) AS avg_activities_per_user,
        COUNT(DISTINCT t.user_id) * 100.0 / NULLIF(COUNT(DISTINCT u.user_id), 0) AS user_activity_rate_pct
    FROM users u
    LEFT JOIN transactions t ON u.user_id = t.user_id
    LEFT JOIN activity a ON u.user_id = a.user_id
    GROUP BY u.plan
),
ultra_metrics AS (
    SELECT * FROM plan_metrics WHERE plan = 'ultra'
),
other_plans_avg AS (
    SELECT 
        AVG(total_users) AS total_users,
        AVG(new_users_30d) AS new_users_30d,
        AVG(total_revenue_gbp) AS total_revenue_gbp,
        AVG(revenue_per_user) AS revenue_per_user,
        AVG(total_transactions) AS total_transactions,
        AVG(transactions_per_user) AS transactions_per_user,
        AVG(transaction_success_rate_pct) AS transaction_success_rate_pct,
        AVG(avg_transaction_amount) AS avg_transaction_amount,
        AVG(avg_activities_per_user) AS avg_activities_per_user,
        AVG(user_activity_rate_pct) AS user_activity_rate_pct
    FROM plan_metrics
    WHERE plan != 'ultra'
)
SELECT 
    'ULTRA' AS plan_type,
    um.total_users,
    um.new_users_30d,
    um.total_revenue_gbp,
    um.revenue_per_user,
    um.total_transactions,
    um.transactions_per_user,
    um.transaction_success_rate_pct,
    um.avg_transaction_amount,
    um.avg_activities_per_user,
    um.user_activity_rate_pct,
    -- Flags: 1 = ULTRA better, 0 = Average better
    CASE WHEN um.revenue_per_user > oa.revenue_per_user THEN 1 ELSE 0 END AS revenue_per_user_flag,
    CASE WHEN um.transaction_success_rate_pct > oa.transaction_success_rate_pct THEN 1 ELSE 0 END AS success_rate_flag,
    CASE WHEN um.transactions_per_user > oa.transactions_per_user THEN 1 ELSE 0 END AS transactions_per_user_flag,
    CASE WHEN um.avg_activities_per_user > oa.avg_activities_per_user THEN 1 ELSE 0 END AS engagement_flag,
    CASE WHEN um.user_activity_rate_pct > oa.user_activity_rate_pct THEN 1 ELSE 0 END AS activity_rate_flag,
    CASE WHEN um.avg_transaction_amount > oa.avg_transaction_amount THEN 1 ELSE 0 END AS avg_amount_flag
FROM ultra_metrics um
CROSS JOIN other_plans_avg oa

UNION ALL

SELECT 
    'AVERAGE (Other Plans)' AS plan_type,
    oa.total_users,
    oa.new_users_30d,
    oa.total_revenue_gbp,
    oa.revenue_per_user,
    oa.total_transactions,
    oa.transactions_per_user,
    oa.transaction_success_rate_pct,
    oa.avg_transaction_amount,
    oa.avg_activities_per_user,
    oa.user_activity_rate_pct,
    -- Flags: 1 = Average better, 0 = ULTRA better (inverse of above)
    CASE WHEN oa.revenue_per_user > um.revenue_per_user THEN 1 ELSE 0 END AS revenue_per_user_flag,
    CASE WHEN oa.transaction_success_rate_pct > um.transaction_success_rate_pct THEN 1 ELSE 0 END AS success_rate_flag,
    CASE WHEN oa.transactions_per_user > um.transactions_per_user THEN 1 ELSE 0 END AS transactions_per_user_flag,
    CASE WHEN oa.avg_activities_per_user > um.avg_activities_per_user THEN 1 ELSE 0 END AS engagement_flag,
    CASE WHEN oa.user_activity_rate_pct > um.user_activity_rate_pct THEN 1 ELSE 0 END AS activity_rate_flag,
    CASE WHEN oa.avg_transaction_amount > um.avg_transaction_amount THEN 1 ELSE 0 END AS avg_amount_flag
FROM other_plans_avg oa
CROSS JOIN ultra_metrics um;

