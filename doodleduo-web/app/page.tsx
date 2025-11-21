'use client'

import { motion } from 'framer-motion'
import Image from 'next/image'
import Link from 'next/link'

const heroHighlights = [
  { label: 'realtime board', icon: '✏️' },
  { label: 'shared farm', icon: '🌱' },
  { label: 'love energy', icon: '💗' },
  { label: 'hardcore survival', icon: '🔥' },
  { label: 'daily prompts', icon: '📅' },
  { label: 'widget hearts', icon: '✨' },
]

const betaSteps = [
  {
    title: 'Install TestFlight',
    detail: 'Download the TestFlight app from the App Store (free).',
  },
  {
    title: 'Join the open beta',
    detail: 'Tap the “Download on TestFlight” button below and accept the invite.',
  },
  {
    title: 'Invite your duo',
    detail: 'Pair inside the app, follow the guided tutorial, then keep your farm alive together.',
  },
]

const updateHighlights = [
  {
    title: 'New survival loop',
    detail: 'Animals now have individual HP bars, hunger timers, and true permadeath. Lose them all and the game resets.',
  },
  {
    title: 'Plant economy revamp',
    detail:
      'Wheat is unlocked from day zero and each crop restores a percentage of the 24h health bar instead of full heals.',
  },
  {
    title: 'Guided onboarding',
    detail: 'Fresh couples are taken through every tab with a soft-lock tutorial, so nothing feels confusing.',
  },
]

export default function Home() {
  return (
    <main className="min-h-screen relative overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0">
        <div className="absolute inset-0 w-full h-full farm-bg-mobile">
          <Image
            src="/images/bg.png"
            alt="Cozy Farm Background"
            fill
            className="object-cover"
            priority
            quality={100}
          />
        </div>
        <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-black/30 to-black/60" />

        <div className="absolute inset-0 overflow-hidden pointer-events-none mobile-hide-glow">
          <motion.div
            className="absolute w-[420px] h-[420px] rounded-full bg-[#ffd4e5]/20 blur-[120px] hw-accelerate"
            animate={{ x: [-80, -40], y: [-260, -260] }}
            transition={{ duration: 3, repeat: Infinity, repeatType: 'reverse', ease: 'easeInOut' }}
          />
          <motion.div
            className="absolute w-[360px] h-[360px] rounded-full bg-[#e8d4ff]/15 blur-[140px] right-0 hw-accelerate"
            animate={{ x: [120, 80], y: [240, 240] }}
            transition={{ duration: 3.6, repeat: Infinity, repeatType: 'reverse', ease: 'easeInOut' }}
          />
        </div>
      </div>

      {/* Content */}
      <div className="relative z-10 flex items-center justify-center min-h-screen px-6 py-16">
        <div className="w-full max-w-[640px] space-y-8">
          {/* Hero */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="relative rounded-[44px] bg-gradient-to-br from-white/95 via-[#fef5f8]/95 to-[#f5f0ff]/95 backdrop-blur-xl p-8 md:p-12 shadow-[0_20px_40px_rgba(0,0,0,0.3)] border border-white/70 overflow-hidden hw-accelerate"
          >
            <motion.div
              className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[210px] h-[210px] rounded-full bg-white/40 blur-[26px]"
              animate={{ scale: [0.97, 1.05, 0.97] }}
              transition={{ duration: 2.4, repeat: Infinity, ease: 'easeInOut' }}
            />

            <div className="relative flex flex-col items-center text-center space-y-4">
              <div className="relative w-[180px] h-[180px] md:w-[210px] md:h-[210px]">
                <Image
                  src="/images/2.png"
                  alt="DoodleDuo Logo"
                  fill
                  className="object-contain drop-shadow-[0_10px_20px_rgba(99,64,59,0.6)]"
                  priority
                />
              </div>

              <h1 className="text-4xl md:text-5xl font-black lowercase text-[#633e3b] tracking-tight">doodleduo</h1>
              <p className="text-xl md:text-2xl font-semibold text-gray-600 lowercase">
                two tiny hearts, one shared survival farm
              </p>

              <div className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-gradient-to-r from-[#1cb5e0] to-[#000851] text-white font-bold text-sm shadow-lg">
                <motion.span
                  animate={{ scale: [1, 1.3, 1], opacity: [1, 0.6, 1] }}
                  transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
                  className="w-2 h-2 rounded-full bg-white"
                />
                open beta live now
              </div>

              <div className="flex flex-col sm:flex-row gap-3 w-full pt-4">
                <Link
                  href="https://testflight.apple.com/join/9H3dkvdb"
                  target="_blank"
                  className="flex-1 inline-flex items-center justify-center gap-2 px-6 py-4 rounded-3xl bg-gradient-to-r from-[#e35070] to-[#ad75ba] text-white font-semibold text-lg shadow-lg hover:shadow-xl transition-shadow"
                >
                  download on testflight
                  <span className="text-2xl">🚀</span>
                </Link>
                <a
                  href="#beta-notes"
                  className="px-6 py-4 rounded-3xl border border-[#ad75ba]/40 text-[#633e3b] font-semibold bg-white/70 backdrop-blur hover:bg-white shadow-sm transition-colors"
                >
                  read what&apos;s new
                </a>
              </div>
            </div>
          </motion.div>

          {/* Highlights */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.5 }}
            className="grid grid-cols-2 md:grid-cols-3 gap-3"
          >
            {heroHighlights.map((feature, i) => (
              <motion.div
                key={feature.label}
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.3 + i * 0.05 }}
                whileHover={{ scale: 1.05, y: -2 }}
                className="flex items-center justify-center gap-2 px-4 py-3 rounded-2xl bg-white/90 backdrop-blur border border-white/60 text-sm font-medium text-gray-800 shadow-lg mobile-simple-shadow cursor-default"
              >
                <span className="text-lg">{feature.icon}</span>
                <span className="lowercase">{feature.label}</span>
              </motion.div>
            ))}
          </motion.div>

          {/* Steps */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4, duration: 0.5 }}
            className="rounded-3xl bg-white/92 backdrop-blur-2xl p-6 md:p-8 shadow-xl border border-white/70 space-y-6"
          >
            <div>
              <p className="uppercase text-xs tracking-[0.3em] text-[#ad75ba] font-bold">how to join</p>
              <h2 className="text-2xl font-black lowercase text-[#2f1c1b]">jump into the open beta</h2>
            </div>
            <div className="space-y-4">
              {betaSteps.map((step, index) => (
                <div key={step.title} className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 rounded-2xl bg-gradient-to-br from-[#e35070] to-[#ad75ba] text-white font-bold flex items-center justify-center shadow-md">
                    {index + 1}
                  </div>
                  <div className="text-left">
                    <p className="text-lg font-semibold lowercase text-[#2f1c1b]">{step.title}</p>
                    <p className="text-sm text-gray-600 lowercase leading-relaxed">{step.detail}</p>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>

          {/* What's new */}
          <motion.div
            id="beta-notes"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5, duration: 0.5 }}
            className="rounded-3xl bg-gradient-to-br from-[#1b2735]/90 to-[#090a0f]/90 text-white p-6 md:p-8 shadow-2xl border border-white/20 space-y-6"
          >
            <div>
              <p className="uppercase text-xs tracking-[0.3em] text-emerald-200 font-bold">this build</p>
              <h2 className="text-2xl font-black lowercase">fresh changes to explore</h2>
            </div>
            <div className="space-y-5">
              {updateHighlights.map((item) => (
                <div key={item.title} className="p-4 rounded-2xl bg-white/10 border border-white/10">
                  <p className="font-semibold text-lg">{item.title}</p>
                  <p className="text-sm text-white/80 leading-relaxed">{item.detail}</p>
                </div>
              ))}
            </div>
            <p className="text-sm text-white/70 lowercase">
              we love detailed feedback—especially around the survival tutorial, plant economy, and game-over reset
              flow. ping us via TestFlight or <a href="mailto:hey@doodleduo.app" className="underline">hey@doodleduo.app</a>.
            </p>
          </motion.div>

          {/* Animal row */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6, duration: 0.5 }}
            className="flex justify-center items-center gap-4 py-4"
          >
            {['chicken', 'pig', 'sheep', 'horse'].map((animal, i) => (
              <motion.div
                key={animal}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.7 + i * 0.1 }}
                whileHover={{ scale: 1.1, rotate: 5 }}
                className="relative w-16 h-16 md:w-20 md:h-20"
              >
                <Image src={`/images/${animal}.png`} alt={animal} fill className="object-contain drop-shadow-lg" />
              </motion.div>
            ))}
          </motion.div>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.8 }}
            className="text-center text-sm text-white/80 drop-shadow-md lowercase"
          >
            made with 💗 for couples who doodle together — see you on the farm
          </motion.p>
        </div>
      </div>
    </main>
  )
}
