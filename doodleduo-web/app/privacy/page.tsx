import Link from 'next/link'

const LAST_UPDATED = 'November 21, 2025'
const SITE_URL = 'https://doodleduoapp.com'

export default function PrivacyPolicy() {
  return (
    <main className="max-w-3xl mx-auto px-6 py-16 space-y-8 text-[#3a2c2b]">
      <header className="space-y-2">
        <p className="text-sm uppercase tracking-[0.4em] text-[#ad75ba]">privacy policy</p>
        <h1 className="text-4xl font-black lowercase">doodleduo privacy commitment</h1>
        <p className="text-sm text-[#7c5e5a]">Last updated: {LAST_UPDATED}</p>
      </header>

      <section className="bg-[#fff9fb] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">1. the essentials</h2>
        <p>
          doodleduo stores the minimum personal data required to keep your shared farm alive: the email address you use
          to sign in, the display name you choose, and optional profile photos. All partner activity data (doodles,
          pings, voice notes) lives inside your private duo room and is never sold or shared with advertisers.
        </p>
      </section>

      <section className="bg-[#fffaf5] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">2. analytics + waitlist</h2>
        <p>
          Our marketing site at {SITE_URL} logs anonymous visit counts so we know how many people are excited about the
          beta. When you join the waitlist we store the email address you provide plus optional referral info so we can
          send invite waves. You can opt out at any time by emailing us.
        </p>
      </section>

      <section className="bg-[#f6fbff] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">3. push notifications</h2>
        <p>
          If you enable notifications we register your device with Apple&apos;s APNs service using an anonymous token. Tokens
          are tied to your duo room only so either partner can receive updates when a doodle lands.
        </p>
      </section>

      <section className="bg-[#fff5ff] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">4. subscriptions</h2>
        <p>
          StoreKit handles payments on your device. doodleduo never sees your credit card details. We only record the fact
          that an active plan exists so the app knows whether to show the paywall. Cancel any time from your Apple ID
          settings and you keep access until the current period ends.
        </p>
      </section>

      <section className="bg-[#fef9f0] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">5. your rights</h2>
        <p>
          Email <Link href="mailto:anthonyverruijtx@hotmail.com" className="text-[#ad75ba] underline">anthonyverruijtx@hotmail.com</Link> if you want your data exported or deleted.
          Removing your duo room permanently erases all doodles, prompts, and device tokens.
        </p>
      </section>

      <footer className="text-sm text-[#7c5e5a]">
        Questions? Reach out at <Link href="mailto:anthonyverruijtx@hotmail.com" className="text-[#ad75ba] underline">anthonyverruijtx@hotmail.com</Link>.
      </footer>
    </main>
  )
}
