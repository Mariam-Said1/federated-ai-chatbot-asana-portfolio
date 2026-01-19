-- =====================================================
-- SQL QUERIES FOR FEDERAL AI CHATBOT PERFORMANCE ANALYSIS
-- =====================================================
-- Author: Associate Product Manager
-- Purpose: Monitor chatbot KPIs, user engagement, and AI model performance
-- Database: PostgreSQL (adapt as needed for your database)
-- Last Updated: January 2026
-- =====================================================

-- =====================================================
-- 1. DAILY CONVERSATION VOLUME & TRENDS
-- =====================================================
-- Track daily conversation volume to monitor adoption and identify trends

SELECT 
    DATE(created_at) AS conversation_date,
    COUNT(DISTINCT conversation_id) AS total_conversations,
    COUNT(DISTINCT user_id) AS unique_users,
    ROUND(AVG(message_count), 2) AS avg_messages_per_conversation,
    ROUND(AVG(duration_seconds) / 60.0, 2) AS avg_duration_minutes
FROM conversations
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY conversation_date DESC;


-- =====================================================
-- 2. CHATBOT ACCURACY & CONFIDENCE SCORES
-- =====================================================
-- Monitor AI model performance and identify low-confidence responses

SELECT 
    DATE(created_at) AS date,
    COUNT(*) AS total_responses,
    ROUND(AVG(confidence_score) * 100, 2) AS avg_confidence_pct,
    COUNT(CASE WHEN confidence_score >= 0.90 THEN 1 END) AS high_confidence_responses,
    COUNT(CASE WHEN confidence_score BETWEEN 0.70 AND 0.89 THEN 1 END) AS medium_confidence_responses,
    COUNT(CASE WHEN confidence_score < 0.70 THEN 1 END) AS low_confidence_responses,
    ROUND(COUNT(CASE WHEN confidence_score < 0.70 THEN 1 END) * 100.0 / COUNT(*), 2) AS escalation_rate_pct
FROM chatbot_responses
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;


-- =====================================================
-- 3. TOP UNANSWERED QUESTIONS (Model Improvement Opportunities)
-- =====================================================
-- Identify questions where chatbot couldn't provide confident answers

SELECT 
    user_question,
    COUNT(*) AS frequency,
    ROUND(AVG(confidence_score) * 100, 2) AS avg_confidence_pct,
    COUNT(DISTINCT user_id) AS unique_users_asking
FROM chatbot_responses
WHERE confidence_score < 0.70
    AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY user_question
HAVING COUNT(*) >= 5  -- Only show questions asked 5+ times
ORDER BY frequency DESC
LIMIT 20;


-- =====================================================
-- 4. USER SATISFACTION SCORES
-- =====================================================
-- Track citizen satisfaction with chatbot responses

SELECT 
    DATE(submitted_at) AS date,
    COUNT(*) AS total_ratings,
    ROUND(AVG(rating) * 100 / 5, 2) AS avg_satisfaction_pct,
    COUNT(CASE WHEN rating >= 4 THEN 1 END) AS positive_ratings,
    COUNT(CASE WHEN rating <= 2 THEN 1 END) AS negative_ratings,
    ROUND(COUNT(CASE WHEN rating >= 4 THEN 1 END) * 100.0 / COUNT(*), 2) AS positive_rate_pct
FROM user_feedback
WHERE submitted_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(submitted_at)
ORDER BY date DESC;


-- =====================================================
-- 5. ESCALATION TO HUMAN AGENTS
-- =====================================================
-- Monitor how often conversations are escalated to human support

SELECT 
    DATE(escalated_at) AS date,
    COUNT(*) AS total_escalations,
    COUNT(DISTINCT conversation_id) AS unique_conversations_escalated,
    ROUND(AVG(messages_before_escalation), 2) AS avg_messages_before_escalation,
    escalation_reason,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY DATE(escalated_at)) AS pct_of_daily_escalations
FROM escalations
WHERE escalated_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(escalated_at), escalation_reason
ORDER BY date DESC, total_escalations DESC;


-- =====================================================
-- 6. CONVERSATION RESOLUTION RATE (First Contact Resolution)
-- =====================================================
-- Measure if users got their answer without needing follow-up

SELECT 
    DATE(c.created_at) AS date,
    COUNT(DISTINCT c.conversation_id) AS total_conversations,
    COUNT(DISTINCT CASE WHEN c.resolved = TRUE THEN c.conversation_id END) AS resolved_conversations,
    ROUND(COUNT(DISTINCT CASE WHEN c.resolved = TRUE THEN c.conversation_id END) * 100.0 / 
          COUNT(DISTINCT c.conversation_id), 2) AS resolution_rate_pct,
    ROUND(AVG(CASE WHEN c.resolved = TRUE THEN c.message_count END), 2) AS avg_messages_when_resolved
FROM conversations c
WHERE c.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(c.created_at)
ORDER BY date DESC;


-- =====================================================
-- 7. MULTILINGUAL USAGE ANALYSIS
-- =====================================================
-- Track language preferences and performance across languages

SELECT 
    language,
    COUNT(DISTINCT conversation_id) AS total_conversations,
    ROUND(COUNT(DISTINCT conversation_id) * 100.0 / 
          SUM(COUNT(DISTINCT conversation_id)) OVER (), 2) AS pct_of_total,
    ROUND(AVG(confidence_score) * 100, 2) AS avg_confidence_pct,
    ROUND(AVG(user_satisfaction), 2) AS avg_satisfaction_score
FROM conversations c
JOIN chatbot_responses r ON c.conversation_id = r.conversation_id
WHERE c.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY language
ORDER BY total_conversations DESC;


-- =====================================================
-- 8. PEAK USAGE HOURS (Capacity Planning)
-- =====================================================
-- Identify high-traffic periods for infrastructure scaling

SELECT 
    EXTRACT(HOUR FROM created_at) AS hour_of_day,
    COUNT(DISTINCT conversation_id) AS total_conversations,
    ROUND(AVG(response_time_ms) / 1000.0, 2) AS avg_response_time_seconds,
    COUNT(CASE WHEN response_time_ms > 3000 THEN 1 END) AS slow_responses
FROM conversations c
JOIN chatbot_responses r ON c.conversation_id = r.conversation_id
WHERE c.created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY hour_of_day;


-- =====================================================
-- 9. CALL CENTER DEFLECTION IMPACT
-- =====================================================
-- Measure how chatbot is reducing call center volume

WITH call_center_baseline AS (
    SELECT AVG(daily_calls) AS baseline_calls
    FROM call_center_metrics
    WHERE date BETWEEN '2025-10-01' AND '2025-12-31'  -- Pre-chatbot baseline
),
post_chatbot AS (
    SELECT 
        DATE(date) AS date,
        daily_calls,
        chatbot_conversations
    FROM call_center_metrics
    WHERE date >= '2026-01-01'  -- Post-chatbot launch
)
SELECT 
    pc.date,
    pc.daily_calls AS current_daily_calls,
    ccb.baseline_calls AS baseline_daily_calls,
    ROUND((ccb.baseline_calls - pc.daily_calls) * 100.0 / ccb.baseline_calls, 2) AS call_reduction_pct,
    pc.chatbot_conversations,
    ROUND(pc.chatbot_conversations * 1.0 / 
          (pc.daily_calls + pc.chatbot_conversations) * 100, 2) AS chatbot_deflection_rate_pct
FROM post_chatbot pc
CROSS JOIN call_center_baseline ccb
ORDER BY pc.date DESC;


-- =====================================================
-- 10. BIAS DETECTION - RESPONSE QUALITY BY DEMOGRAPHIC
-- =====================================================
-- Monitor for potential bias in AI responses across user demographics

SELECT 
    u.demographic_group,
    COUNT(DISTINCT r.conversation_id) AS total_conversations,
    ROUND(AVG(r.confidence_score) * 100, 2) AS avg_confidence_pct,
    ROUND(AVG(f.rating), 2) AS avg_satisfaction_rating,
    COUNT(CASE WHEN r.confidence_score < 0.70 THEN 1 END) AS low_confidence_responses,
    ROUND(COUNT(CASE WHEN r.confidence_score < 0.70 THEN 1 END) * 100.0 / COUNT(*), 2) AS low_confidence_rate_pct
FROM chatbot_responses r
JOIN conversations c ON r.conversation_id = c.conversation_id
JOIN users u ON c.user_id = u.user_id
LEFT JOIN user_feedback f ON c.conversation_id = f.conversation_id
WHERE r.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.demographic_group
ORDER BY total_conversations DESC;


-- =====================================================
-- 11. MOST COMMON USER INTENTS
-- =====================================================
-- Understand what users are primarily asking about

SELECT 
    intent_category,
    COUNT(*) AS frequency,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    ROUND(AVG(confidence_score) * 100, 2) AS avg_confidence_pct,
    ROUND(AVG(response_time_ms) / 1000.0, 2) AS avg_response_time_sec
FROM chatbot_responses
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND intent_category IS NOT NULL
GROUP BY intent_category
ORDER BY frequency DESC
LIMIT 15;


-- =====================================================
-- 12. ACCESSIBILITY FEATURE USAGE
-- =====================================================
-- Track adoption of accessibility features (screen readers, text-to-speech)

SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT CASE WHEN screen_reader_used = TRUE THEN user_id END) AS screen_reader_users,
    COUNT(DISTINCT CASE WHEN text_to_speech_used = TRUE THEN user_id END) AS tts_users,
    COUNT(DISTINCT CASE WHEN keyboard_navigation_only = TRUE THEN user_id END) AS keyboard_nav_users,
    COUNT(DISTINCT user_id) AS total_users,
    ROUND(COUNT(DISTINCT CASE WHEN screen_reader_used = TRUE THEN user_id END) * 100.0 / 
          COUNT(DISTINCT user_id), 2) AS accessibility_usage_pct
FROM conversations
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;


-- =====================================================
-- 13. SYSTEM PERFORMANCE & UPTIME
-- =====================================================
-- Monitor technical performance and identify issues

SELECT 
    DATE(timestamp) AS date,
    COUNT(*) AS total_requests,
    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95_response_time_ms,
    COUNT(CASE WHEN status_code = 200 THEN 1 END) AS successful_requests,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END) AS failed_requests,
    ROUND(COUNT(CASE WHEN status_code = 200 THEN 1 END) * 100.0 / COUNT(*), 2) AS success_rate_pct
FROM system_logs
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;


-- =====================================================
-- 14. COMPLIANCE AUDIT TRAIL
-- =====================================================
-- Generate audit logs for FedRAMP compliance reporting

SELECT 
    c.conversation_id,
    c.user_id,
    u.clearance_level,
    c.created_at AS conversation_start,
    c.ended_at AS conversation_end,
    COUNT(r.response_id) AS total_responses,
    BOOL_OR(r.contains_pii) AS pii_accessed,
    BOOL_OR(c.escalated) AS was_escalated,
    c.data_retention_expires_at
FROM conversations c
JOIN users u ON c.user_id = u.user_id
LEFT JOIN chatbot_responses r ON c.conversation_id = r.conversation_id
WHERE c.created_at >= CURRENT_DATE - INTERVAL '90 days'
    AND (r.contains_pii = TRUE OR c.escalated = TRUE)
GROUP BY c.conversation_id, c.user_id, u.clearance_level, c.created_at, c.ended_at, c.data_retention_expires_at
ORDER BY c.created_at DESC;


-- =====================================================
-- 15. EXECUTIVE SUMMARY DASHBOARD
-- =====================================================
-- High-level KPIs for leadership reporting

WITH metrics AS (
    SELECT 
        COUNT(DISTINCT c.conversation_id) AS total_conversations,
        COUNT(DISTINCT c.user_id) AS unique_users,
        ROUND(AVG(r.confidence_score) * 100, 2) AS avg_confidence_pct,
        ROUND(AVG(f.rating), 2) AS avg_satisfaction_rating,
        COUNT(CASE WHEN c.escalated = TRUE THEN 1 END) AS escalations,
        ROUND(COUNT(CASE WHEN c.resolved = TRUE THEN 1 END) * 100.0 / 
              COUNT(DISTINCT c.conversation_id), 2) AS resolution_rate_pct
    FROM conversations c
    LEFT JOIN chatbot_responses r ON c.conversation_id = r.conversation_id
    LEFT JOIN user_feedback f ON c.conversation_id = f.conversation_id
    WHERE c.created_at >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    'Last 30 Days' AS period,
    total_conversations,
    unique_users,
    avg_confidence_pct,
    avg_satisfaction_rating,
    escalations,
    ROUND(escalations * 100.0 / total_conversations, 2) AS escalation_rate_pct,
    resolution_rate_pct
FROM metrics;


-- =====================================================
-- NOTES FOR IMPLEMENTATION:
-- =====================================================
-- 1. Adjust table/column names to match your actual database schema
-- 2. Add indexes on frequently queried columns (created_at, conversation_id, user_id)
-- 3. Consider creating materialized views for expensive queries (e.g., daily aggregations)
-- 4. Schedule these queries to run automatically for daily/weekly reporting
-- 5. Integrate results with BI tools (Tableau, Looker, etc.) for visualization
-- 6. Set up alerts when KPIs fall below thresholds (e.g., satisfaction < 80%)
-- =====================================================