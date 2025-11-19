-- Question 4: Fraud Detection - Suspicious Activity Identification
-- This query flags potentially fraudulent transactions based on multiple risk indicators

WITH user_transaction_stats AS (
    -- Calculate baseline statistics per user for anomaly detection
    SELECT 
        user_id,
        AVG(amount_gbp) AS avg_transaction_amount,
        STDDEV(amount_gbp) AS stddev_transaction_amount,
        COUNT(*) AS total_transaction_count,
        COUNT(DISTINCT ip_address) AS unique_ip_count
    FROM transactions
    WHERE state = 'completed'
    GROUP BY user_id
),
transaction_velocity AS (
    -- Detect rapid-fire transactions (potential card testing or fraud)
    -- Using window function with RANGE for efficient time-based counting
    SELECT 
        transaction_id,
        user_id,
        COUNT(*) OVER (
            PARTITION BY user_id 
            ORDER BY created_date 
            RANGE BETWEEN INTERVAL 1 HOUR PRECEDING AND CURRENT ROW
        ) AS transactions_in_1hour
    FROM transactions
),
ip_anomaly_detection AS (
    -- Flag transactions from IPs used by multiple different users (potential shared/fake IPs)
    SELECT 
        ip_address,
        COUNT(DISTINCT user_id) AS unique_users_per_ip,
        COUNT(*) AS total_transactions_per_ip
    FROM transactions
    WHERE created_date >= CURRENT_TIMESTAMP - INTERVAL 7 DAY
    GROUP BY ip_address
    HAVING COUNT(DISTINCT user_id) > 3  -- IP used by more than 3 different users
),
failed_transaction_pattern AS (
    -- Identify users with high failure rates (potential testing or stolen cards)
    SELECT 
        user_id,
        COUNT(CASE WHEN state = 'failed' THEN 1 END) * 100.0 / COUNT(*) AS failure_rate_pct,
        COUNT(CASE WHEN state = 'failed' THEN 1 END) AS failed_count
    FROM transactions
    WHERE created_date >= CURRENT_TIMESTAMP - INTERVAL 7 DAY
    GROUP BY user_id
    HAVING COUNT(CASE WHEN state = 'failed' THEN 1 END) >= 3  -- At least 3 failed transactions
)
SELECT 
    t.transaction_id,
    t.user_id,
    u.country AS user_country,
    t.ip_address,
    t.created_date,
    t.direction,
    t.amount_gbp,
    t.state,
    -- Risk indicators
    CASE 
        WHEN t.amount_gbp > (uts.avg_transaction_amount + 3 * uts.stddev_transaction_amount) 
        THEN 1 ELSE 0 
    END AS unusual_amount_flag,  -- Amount significantly above user's average
    
    CASE 
        WHEN tv.transactions_in_1hour >= 5 
        THEN 1 ELSE 0 
    END AS high_velocity_flag,  -- 5+ transactions in 1 hour
    
    CASE 
        WHEN iad.unique_users_per_ip > 3 
        THEN 1 ELSE 0 
    END AS shared_ip_flag,  -- IP used by multiple users
    
    CASE 
        WHEN ftp.failure_rate_pct > 50 AND ftp.failed_count_7d >= 3
        THEN 1 ELSE 0 
    END AS high_failure_rate_flag,  -- User has high failure rate in rolling 7-day window
    
    CASE 
        WHEN t.state = 'failed' AND ftp.failed_count_7d >= 3
        THEN 1 ELSE 0 
    END AS repeated_failure_flag,  -- Part of a pattern of failures in rolling 7-day window
    
    -- Calculate risk score (0-5, higher = more suspicious)
    (
        CASE WHEN t.amount_gbp > (uts.avg_transaction_amount + 3 * uts.stddev_transaction_amount) THEN 1 ELSE 0 END +
        CASE WHEN tv.transactions_in_1hour >= 5 THEN 1 ELSE 0 END +
        CASE WHEN iad.unique_users_per_ip > 3 THEN 1 ELSE 0 END +
        CASE WHEN ftp.failure_rate_pct > 50 AND ftp.failed_count_7d >= 3 THEN 1 ELSE 0 END +
        CASE WHEN t.state = 'failed' AND ftp.failed_count_7d >= 3 THEN 1 ELSE 0 END
    ) AS risk_score,
    
    -- Additional context
    tv.transactions_in_1hour,
    iad.unique_users_per_ip AS users_sharing_ip,
    ftp.failure_rate_pct,
    ftp.failed_count_7d,
    uts.avg_transaction_amount AS user_avg_amount
    
FROM transactions t
INNER JOIN users u ON t.user_id = u.user_id
LEFT JOIN user_transaction_stats uts ON t.user_id = uts.user_id
LEFT JOIN transaction_velocity tv ON t.transaction_id = tv.transaction_id
LEFT JOIN ip_anomaly_detection iad ON t.ip_address = iad.ip_address
LEFT JOIN failed_transaction_pattern ftp ON t.transaction_id = ftp.transaction_id
WHERE t.created_date >= CURRENT_TIMESTAMP - INTERVAL 30 DAY  -- Focus on recent transactions
ORDER BY 
    risk_score DESC,
    t.created_date DESC
LIMIT 100;  -- Top 100 most suspicious transactions

