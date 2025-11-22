import Link from 'next/link'

const LAST_UPDATED = 'November 21, 2025'
const SITE_URL = 'https://doodleduoapp.com'

export default function TermsOfService() {
  return (
    <main className="max-w-3xl mx-auto px-6 py-16 space-y-8 text-[#3a2c2b]">
      <header className="space-y-2">
        <p className="text-sm uppercase tracking-[0.4em] text-[#ad75ba]">terms of service</p>
        <h1 className="text-4xl font-black lowercase">doodleduo rules for cozy play</h1>
        <p className="text-sm text-[#7c5e5a]">Last updated: {LAST_UPDATED}</p>
      </header>

      <section className="bg-[#fff9fb] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">1. eligibility</h2>
        <p>
          doodleduo is designed for adults who want to nurture a relationship in a safe space. By using the app you
          confirm you are at least 18 years old and legally allowed to form a binding agreement in your region.
        </p>
      </section>

      <section className="bg-[#fffaf5] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">2. account + duo rooms</h2>
        <p>
          Every account is tied to an email address. Inviting a partner creates a shared duo room where both of you can
          post content. Please only add people you trust—anything you create is visible to your partner.
        </p>
      </section>

      <section className="bg-[#f6fbff] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">3. subscriptions</h2>
        <p>
          doodleduo Pro is billed through Apple using auto-renewing subscriptions (monthly or yearly). Payment is turned
          on via your Apple ID and renews until canceled at least 24 hours before the current period ends. You can
          manage or cancel from <strong>Settings → Apple ID → Subscriptions</strong>. No refunds are handled by doodleduo directly.
        </p>
      </section>

      <section className="bg-[#fff5ff] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">4. acceptable use</h2>
        <p>
          Keep doodleduo respectful—no harassment, spam, or illegal content. We may suspend accounts that violate these
          guidelines or Apple&apos;s platform rules.
        </p>
      </section>

      <section className="bg-[#fef9f0] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">5. termination</h2>
        <p>
          You can delete your duo room or account at any time via the app or by emailing us. We reserve the right to
          terminate or limit access if necessary to protect users or comply with law.
        </p>
      </section>

      <section className="bg-[#fff9fb] rounded-3xl p-6 space-y-4 shadow-sm">
        <h2 className="text-2xl font-semibold lowercase">6. contact</h2>
        <p>
          Questions about these terms or billing? Email <Link href="mailto:anthonyverruijtx@hotmail.com" className="text-[#ad75ba] underline">anthonyverruijtx@hotmail.com</Link> or visit {SITE_URL}.
        </p>
      </section>
    </main>
  )
}
