-- Remove legacy push trigger to prevent duplicate notifications
-- Earlier migration 003 created trigger_notify_partner_of_activity.
-- After activating the new notify_partner_on_activity trigger we only need one.

DROP TRIGGER IF EXISTS trigger_notify_partner_of_activity ON public.duo_activities;

DO $$
BEGIN
    RAISE NOTICE '✅ Removed legacy trigger_notify_partner_of_activity (if it existed)';
    RAISE NOTICE '✅ Only notify_partner_on_activity will run going forward';
END $$;
