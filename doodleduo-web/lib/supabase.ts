import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

export interface WaitlistEntry {
  email: string
  referral_source?: string
  user_agent?: string
}

export async function joinWaitlist(entry: WaitlistEntry) {
  const { data, error } = await supabase
    .from('waitlist')
    .insert([entry])
    .select()
    .single()

  if (error) {
    // Check if it's a duplicate email error
    if (error.code === '23505') {
      throw new Error('This email is already on the waitlist!')
    }
    throw error
  }

  return data
}

export async function getWaitlistCount(): Promise<number> {
  const { count, error } = await supabase
    .from('waitlist')
    .select('*', { count: 'exact', head: true })

  if (error) {
    console.error('Error fetching waitlist count:', error)
    return 0
  }

  return count || 0
}
