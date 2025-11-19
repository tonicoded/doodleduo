'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import Image from 'next/image'
import { joinWaitlist, getWaitlistCount } from '@/lib/supabase'

export default function Home() {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle')
  const [errorMessage, setErrorMessage] = useState('')
  const [waitlistCount, setWaitlistCount] = useState<number | null>(null)

  useEffect(() => {
    // Load waitlist count on mount
    getWaitlistCount().then(count => setWaitlistCount(count)).catch(() => setWaitlistCount(null))
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setStatus('loading')
    setErrorMessage('')

    try {
      await joinWaitlist({
        email,
        referral_source: document.referrer || 'direct',
        user_agent: navigator.userAgent,
      })
      setStatus('success')
      setEmail('')
      // Refresh waitlist count
      const newCount = await getWaitlistCount()
      setWaitlistCount(newCount)
    } catch (error: any) {
      setStatus('error')
      setErrorMessage(error.message || 'Something went wrong. Please try again.')
    }
  }

  return (
    <main className="min-h-screen relative overflow-hidden">
      {/* Farm background with overlay */}
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
        {/* Gradient overlay for better text readability */}
        <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-black/30 to-black/50" />

        {/* Animated glow effects - hidden on mobile for performance */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none mobile-hide-glow">
          <motion.div
            className="absolute w-[420px] h-[420px] rounded-full bg-[#ffd4e5]/20 blur-[120px] hw-accelerate"
            animate={{
              x: [-80, -40],
              y: [-260, -260],
            }}
            transition={{
              duration: 3,
              repeat: Infinity,
              repeatType: 'reverse',
              ease: 'easeInOut',
            }}
          />
          <motion.div
            className="absolute w-[360px] h-[360px] rounded-full bg-[#e8d4ff]/15 blur-[140px] right-0 hw-accelerate"
            animate={{
              x: [120, 80],
              y: [240, 240],
            }}
            transition={{
              duration: 3.6,
              repeat: Infinity,
              repeatType: 'reverse',
              ease: 'easeInOut',
            }}
          />
        </div>
      </div>

      {/* Content */}
      <div className="relative z-10 flex items-center justify-center min-h-screen px-6 py-16">
        <div className="w-full max-w-[520px] space-y-6">
          {/* Hero Card */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="relative rounded-[44px] bg-gradient-to-br from-white/95 via-[#fef5f8]/95 to-[#f5f0ff]/95 backdrop-blur-xl mobile-optimize-blur p-8 md:p-12 shadow-[0_20px_40px_rgba(0,0,0,0.3)] mobile-simple-shadow border border-white/70 hw-accelerate"
          >
            {/* Animated hearts overlay */}
            <div className="absolute inset-0 overflow-hidden rounded-[44px] pointer-events-none">
              {[...Array(5)].map((_, i) => (
                <FloatingHeart key={i} delay={i * 0.2} index={i} />
              ))}
            </div>

            {/* Glow effect behind logo */}
            <motion.div
              className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[210px] h-[210px] rounded-full bg-white/40 blur-[26px]"
              animate={{ scale: [0.97, 1.05, 0.97] }}
              transition={{ duration: 2.4, repeat: Infinity, ease: 'easeInOut' }}
            />

            <div className="relative flex flex-col items-center text-center space-y-4">
              {/* Logo */}
              <motion.div
                initial={{ scale: 0.8, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ delay: 0.2, duration: 0.5 }}
                className="relative w-[180px] h-[180px] md:w-[210px] md:h-[210px]"
              >
                <Image
                  src="/images/2.png"
                  alt="DoodleDuo Logo"
                  fill
                  className="object-contain drop-shadow-[0_10px_20px_rgba(99,64,59,0.6)]"
                  priority
                />
              </motion.div>

              {/* Title */}
              <motion.h1
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.4 }}
                className="text-4xl md:text-5xl font-black lowercase text-[#633e3b] tracking-tight"
              >
                doodleduo
              </motion.h1>

              {/* Subtitle */}
              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.5 }}
                className="text-xl md:text-2xl font-semibold text-gray-600 lowercase"
              >
                two tiny hearts, one shared farm
              </motion.p>

              {/* Beta badge */}
              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.6 }}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-gradient-to-r from-[#e35070] to-[#ad75ba] text-white font-bold text-sm shadow-lg"
              >
                <motion.span
                  animate={{
                    scale: [1, 1.3, 1],
                    opacity: [1, 0.6, 1],
                  }}
                  transition={{
                    duration: 2,
                    repeat: Infinity,
                    ease: 'easeInOut',
                  }}
                  className="w-2 h-2 rounded-full bg-white"
                />
                beta starts soon
              </motion.div>
            </div>
          </motion.div>

          {/* Description */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.7, duration: 0.5 }}
            className="text-center space-y-3 px-4 py-6 rounded-3xl bg-white/90 backdrop-blur-md mobile-optimize-blur shadow-lg mobile-simple-shadow border border-white/60 hw-accelerate"
          >
            <h2 className="text-2xl md:text-3xl font-bold lowercase text-gray-900">
              live cozy doodles for couples
            </h2>
            <p className="text-base md:text-lg text-gray-700 lowercase leading-relaxed">
              sketch love notes, leave tiny dares, toss love pings, and level up a gentle farm that mirrors your vibe.
            </p>
          </motion.div>

          {/* Feature chips */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.8, duration: 0.5 }}
            className="grid grid-cols-2 md:grid-cols-3 gap-3"
          >
            {[
              { label: 'realtime board', icon: '✏️' },
              { label: 'cozy farm', icon: '🌱' },
              { label: 'widget hearts', icon: '✨' },
              { label: 'hardcore streak', icon: '🔥' },
              { label: 'daily prompts', icon: '📅' },
              { label: 'love pings', icon: '💗' },
            ].map((feature, i) => (
              <motion.div
                key={feature.label}
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.9 + i * 0.05 }}
                whileHover={{ scale: 1.05, y: -2 }}
                className="flex items-center justify-center gap-2 px-4 py-3 rounded-2xl bg-white/85 backdrop-blur-md mobile-optimize-blur border border-white/50 text-sm font-medium text-gray-800 shadow-lg mobile-simple-shadow hover:shadow-xl hover:bg-white/95 transition-all cursor-default hw-accelerate"
              >
                <span className="text-lg">{feature.icon}</span>
                <span className="lowercase">{feature.label}</span>
              </motion.div>
            ))}
          </motion.div>

          {/* Waitlist form */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 1, duration: 0.5 }}
          >
            <AnimatePresence mode="wait">
              {status === 'success' ? (
                <motion.div
                  key="success"
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.9 }}
                  className="p-6 rounded-3xl bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 text-center"
                >
                  <div className="text-4xl mb-3">🎉</div>
                  <h3 className="text-xl font-bold text-green-800 mb-2 lowercase">
                    you&apos;re on the list!
                  </h3>
                  <p className="text-green-700 lowercase">
                    we&apos;ll notify you when beta launches
                  </p>
                </motion.div>
              ) : (
                <motion.form
                  key="form"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  onSubmit={handleSubmit}
                  className="space-y-4"
                >
                  <div className="flex flex-col sm:flex-row gap-3">
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="your email"
                      required
                      disabled={status === 'loading'}
                      className="flex-1 px-6 py-4 rounded-3xl bg-white/80 backdrop-blur-sm border border-white/60 text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#e35070] focus:border-transparent shadow-sm lowercase disabled:opacity-50"
                    />
                    <motion.button
                      type="submit"
                      disabled={status === 'loading'}
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      className="px-8 py-4 rounded-3xl bg-gradient-to-r from-[#e35070] to-[#ad75ba] text-white font-bold shadow-lg hover:shadow-xl transition-shadow disabled:opacity-50 disabled:cursor-not-allowed lowercase flex items-center justify-center gap-2"
                    >
                      {status === 'loading' ? (
                        <>
                          <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                          <span>joining...</span>
                        </>
                      ) : (
                        <>
                          <span>join waitlist</span>
                          <span className="text-xl">💗</span>
                        </>
                      )}
                    </motion.button>
                  </div>

                  {status === 'error' && (
                    <motion.p
                      initial={{ opacity: 0, y: -10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="text-red-600 text-sm text-center lowercase"
                    >
                      {errorMessage}
                    </motion.p>
                  )}
                </motion.form>
              )}
            </AnimatePresence>
          </motion.div>

          {/* Animal showcase */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 1.1, duration: 0.5 }}
            className="flex justify-center items-center gap-4 py-4"
          >
            {['chicken', 'pig', 'sheep', 'horse'].map((animal, i) => (
              <motion.div
                key={animal}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 1.2 + i * 0.1 }}
                whileHover={{ scale: 1.1, rotate: 5 }}
                className="relative w-16 h-16 md:w-20 md:h-20"
              >
                <Image
                  src={`/images/${animal}.png`}
                  alt={animal}
                  fill
                  className="object-contain drop-shadow-lg"
                />
              </motion.div>
            ))}
          </motion.div>

          {/* Waitlist Counter */}
          {waitlistCount !== null && waitlistCount > 0 && (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 1.3, duration: 0.5 }}
              className="flex items-center justify-center gap-2 px-6 py-3 rounded-full bg-gradient-to-r from-[#e35070]/20 to-[#ad75ba]/20 backdrop-blur-md border border-white/40"
            >
              <motion.span
                key={waitlistCount}
                initial={{ scale: 1.5, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                className="text-2xl font-black text-white drop-shadow-lg"
              >
                {waitlistCount}
              </motion.span>
              <span className="text-sm font-medium text-white/90 lowercase">
                {waitlistCount === 1 ? 'person' : 'people'} ready for beta 🎉
              </span>
            </motion.div>
          )}

          {/* Footer text */}
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.4 }}
            className="text-center text-sm text-white/80 drop-shadow-md lowercase"
          >
            made with 💗 for couples who doodle together
          </motion.p>
        </div>
      </div>
    </main>
  )
}

// Floating heart animation component
function FloatingHeart({ delay, index }: { delay: number; index: number }) {
  const colors = [
    'rgb(248, 158, 186)', // pink
    'rgb(222, 125, 200)', // pink-purple
    'rgb(194, 135, 219)', // purple
    'rgb(214, 168, 239)', // light purple
    'rgb(239, 175, 208)', // light pink
  ]

  const startX = [20, 45, 65, 85, 35][index] || 50
  const amplitude = [18, 22, 26, 18, 24][index] || 20

  return (
    <motion.div
      className="absolute"
      initial={{ opacity: 0 }}
      animate={{
        opacity: [0, 0.75, 0.75, 0],
        y: ['100%', '-20%'],
        x: [
          `${startX}%`,
          `${startX + amplitude / 2}%`,
          `${startX}%`,
          `${startX - amplitude / 2}%`,
          `${startX}%`,
        ],
      }}
      transition={{
        duration: 8,
        delay,
        repeat: Infinity,
        ease: 'linear',
      }}
      style={{ left: 0, bottom: 0 }}
    >
      <svg
        width="20"
        height="18"
        viewBox="0 0 20 18"
        fill={colors[index % colors.length]}
        className="drop-shadow-sm opacity-75 blur-[0.4px]"
      >
        <path d="M10 17.5C10 17.5 1 12 1 5.5C1 3.5 2.5 2 4.5 2C6.5 2 8.5 3.5 10 5.5C11.5 3.5 13.5 2 15.5 2C17.5 2 19 3.5 19 5.5C19 12 10 17.5 10 17.5Z" />
      </svg>
    </motion.div>
  )
}
