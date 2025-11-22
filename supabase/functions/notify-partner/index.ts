import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  roomId: string
  senderName: string
  activityType: string
  activityId: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Parse request body
    const { roomId, senderName, activityType, activityId }: NotificationPayload = await req.json()

    // Get partner's user ID from the room
    const { data: memberships, error: membershipError } = await supabaseClient
      .from('duo_memberships')
      .select('profile_id')
      .eq('room_id', roomId)

    if (membershipError || !memberships || memberships.length < 2) {
      console.error('Could not find room members:', membershipError)
      return new Response(
        JSON.stringify({ error: 'Room not found or incomplete' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get auth header to identify sender
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: authUser, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !authUser.user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Find partner (the other member who isn't the sender)
    const partnerId = memberships.find(m => m.profile_id !== authUser.user.id)?.profile_id

    if (!partnerId) {
      console.log('No partner found for notification')
      return new Response(
        JSON.stringify({ success: true, message: 'No partner to notify' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get partner's device tokens
    const { data: deviceTokens, error: tokenError } = await supabaseClient
      .from('device_tokens')
      .select('device_token')
      .eq('user_id', partnerId)

    if (tokenError) {
      console.error('Could not fetch device tokens:', tokenError)
      return new Response(
        JSON.stringify({ error: 'Could not fetch device tokens' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!deviceTokens || deviceTokens.length === 0) {
      console.log('No device tokens found for partner')
      return new Response(
        JSON.stringify({ success: true, message: 'Partner has no device tokens' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Send push notifications to all partner's devices
    const notifications = deviceTokens.map(async (token) => {
      const pushPayload = {
        to: token.device_token,
        title: `${senderName} sent a doodle`,
        body: 'Tap to see their latest creation! 🎨',
        data: {
          activity_type: activityType,
          activity_id: activityId,
          widget_refresh: true,
          room_id: roomId
        },
        sound: 'default',
        badge: 1
      }

      try {
        const response = await fetch('https://exp.host/--/api/v2/push/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Accept-Encoding': 'gzip, deflate',
          },
          body: JSON.stringify(pushPayload)
        })

        const result = await response.json()
        console.log('Push notification sent:', result)
        return result
      } catch (error) {
        console.error('Failed to send push notification:', error)
        return { error: error.message }
      }
    })

    const results = await Promise.all(notifications)
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Sent ${results.length} notification(s)`,
        results 
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})