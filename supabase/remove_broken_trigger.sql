-- Remove the broken trigger that's preventing doodle creation
DROP TRIGGER IF EXISTS trigger_doodle_notification ON duo_activities;
DROP FUNCTION IF EXISTS notify_partner_of_doodle();
DROP FUNCTION IF EXISTS send_push_notification(UUID, TEXT, TEXT, JSONB);