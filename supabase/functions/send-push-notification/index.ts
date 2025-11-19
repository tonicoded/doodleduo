import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  device_token: string
  activity_type: string
  content?: string
  room_id: string
  partner_name?: string
  activity_id?: string
  widget_refresh?: boolean
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: NotificationPayload = await req.json()
    
    console.log('📲 Sending push notification:', payload)

    const shouldRefreshWidget = payload.widget_refresh === true || payload.activity_type === 'doodle'

    // Create the APNs payload
    const apsPayload: Record<string, unknown> = {
      alert: {
        title: getNotificationTitle(payload.activity_type, payload.partner_name || "Your partner"),
        body: getNotificationBody(payload.activity_type, payload.content)
      },
      sound: "default",
      badge: 1
    }

    if (shouldRefreshWidget) {
      apsPayload['content-available'] = 1
    }

    const apnsPayload = {
      aps: apsPayload,
      activity_type: payload.activity_type,
      room_id: payload.room_id,
      activity_id: payload.activity_id,
      // Custom data to trigger widget refresh
      widget_refresh: shouldRefreshWidget
    }

    // Send to APNs (Apple Push Notification service)
    const apnsResponse = await sendToAPNs(payload.device_token, apnsPayload)

    console.log('✅ APNs response:', apnsResponse.status)

    // Log error details if not successful
    if (!apnsResponse.ok) {
      const errorBody = await apnsResponse.text()
      console.error('❌ APNs error response:', errorBody)
    }

    return new Response(
      JSON.stringify({
        success: apnsResponse.ok,
        status: apnsResponse.status
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: apnsResponse.ok ? 200 : 500,
      }
    )

  } catch (error) {
    console.error('❌ Push notification error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

function getNotificationTitle(activityType: string, partnerName: string): string {
  switch (activityType) {
    case 'doodle':
      return `New Doodle from ${partnerName} 🎨`
    case 'ping':
      return `${partnerName} is thinking of you 💝`
    case 'note':
      return `${partnerName} sent a note 📝`
    case 'hug':
      return `${partnerName} sent you a hug 🤗`
    case 'kiss':
      return `${partnerName} sent you a kiss 💋`
    default:
      return `New activity from ${partnerName}`
  }
}

function getNotificationBody(activityType: string, content?: string): string {
  switch (activityType) {
    case 'doodle':
      return "Your partner just shared a doodle with you!"
    case 'ping':
      return "Your partner sent you a ping!"
    case 'note':
      return content && content.length > 0 ? content : "They shared something with you"
    case 'hug':
      return "Your partner is giving you a virtual hug!"
    case 'kiss':
      return "Your partner is sending you love!"
    default:
      return "Check the app to see what they shared!"
  }
}

async function sendToAPNs(deviceToken: string, payload: any): Promise<Response> {
  // Check if we should use production or sandbox APNs
  const isProduction = Deno.env.get('APNS_PRODUCTION') === 'true'
  const apnsUrl = isProduction
    ? `https://api.push.apple.com/3/device/${deviceToken}`
    : `https://api.sandbox.push.apple.com/3/device/${deviceToken}`

  console.log('📡 Using APNs environment:', isProduction ? 'Production' : 'Sandbox')
  
  // You'll need to set these in Supabase environment variables
  const teamId = Deno.env.get('APPLE_TEAM_ID') || 'YOUR_TEAM_ID'
  const keyId = Deno.env.get('APPLE_KEY_ID') || 'YOUR_KEY_ID' 
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID') || 'com.anthony.doodleduo'
  const privateKey = Deno.env.get('APPLE_PRIVATE_KEY') || 'YOUR_PRIVATE_KEY'

  // Create JWT token for APNs authentication
  const jwt = await createAPNsJWT(teamId, keyId, privateKey)

  const headers = {
    'authorization': `bearer ${jwt}`,
    'apns-topic': bundleId,
    'apns-push-type': 'alert',
    'apns-priority': '10',
    'content-type': 'application/json'
  }

  return fetch(apnsUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload)
  })
}

async function createAPNsJWT(teamId: string, keyId: string, privateKey: string): Promise<string> {
  console.log('🔐 Creating APNs JWT token...')

  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'ES256', kid: keyId }
  const claims = { iss: teamId, iat: now }

  const encoder = new TextEncoder()
  const headerEncoded = base64UrlEncode(encoder.encode(JSON.stringify(header)))
  const claimsEncoded = base64UrlEncode(encoder.encode(JSON.stringify(claims)))
  const dataToSign = `${headerEncoded}.${claimsEncoded}`

  const cryptoKey = await importPrivateKey(privateKey)
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: 'ECDSA', hash: { name: 'SHA-256' } },
      cryptoKey,
      encoder.encode(dataToSign)
    )
  )

  const joseSignature = toJoseSignature(signature)
  const signatureEncoded = base64UrlEncode(joseSignature)

  return `${dataToSign}.${signatureEncoded}`
}

function base64UrlEncode(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function toJoseSignature(signature: Uint8Array): Uint8Array {
  if (signature.length === 64) {
    // Already in JOSE (r||s) format
    return signature
  }
  return derToJose(signature)
}

async function importPrivateKey(privateKey: string): Promise<CryptoKey> {
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'

  // Handle both multi-line and single-line formats
  let pemContents = privateKey
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\\n/g, '') // Remove literal \n characters
    .replace(/\s/g, '')  // Remove all whitespace
    .trim()

  console.log('🔑 Private key length after processing:', pemContents.length)

  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  return crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    {
      name: 'ECDSA',
      namedCurve: 'P-256',
    },
    false,
    ['sign']
  )
}

function derToJose(signature: Uint8Array): Uint8Array {
  if (signature[0] !== 0x30) {
    throw new Error('Invalid DER signature format')
  }

  let offset = 1
  const sequence = readLength(signature, offset)
  offset = sequence.offset

  if (signature[offset++] !== 0x02) {
    throw new Error('Invalid DER signature - missing R component')
  }

  const rInfo = readLength(signature, offset)
  const r = signature.slice(rInfo.offset, rInfo.offset + rInfo.length)
  offset = rInfo.offset + rInfo.length

  if (signature[offset++] !== 0x02) {
    throw new Error('Invalid DER signature - missing S component')
  }

  const sInfo = readLength(signature, offset)
  const s = signature.slice(sInfo.offset, sInfo.offset + sInfo.length)

  const rPadded = normalizeScalar(r)
  const sPadded = normalizeScalar(s)

  const joseSignature = new Uint8Array(64)
  joseSignature.set(rPadded, 0)
  joseSignature.set(sPadded, 32)

  return joseSignature
}

function normalizeScalar(bytes: Uint8Array): Uint8Array {
  let trimmed = bytes

  while (trimmed.length > 0 && trimmed[0] === 0x00) {
    trimmed = trimmed.slice(1)
  }

  if (trimmed.length > 32) {
    trimmed = trimmed.slice(trimmed.length - 32)
  }

  const padded = new Uint8Array(32)
  padded.set(trimmed, 32 - trimmed.length)
  return padded
}

function readLength(bytes: Uint8Array, offset: number): { length: number; offset: number } {
  let length = bytes[offset]
  offset += 1

  if (length & 0x80) {
    const numBytes = length & 0x7f
    length = 0
    for (let i = 0; i < numBytes; i++) {
      length = (length << 8) | bytes[offset + i]
    }
    offset += numBytes
  }

  return { length, offset }
}
