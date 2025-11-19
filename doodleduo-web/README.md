# DoodleDuo Beta Waitlist Website 💗

Beautiful, responsive landing page for DoodleDuo - a cozy couples app where shared doodles make a tiny world grow.

## ✨ Features

- **Stunning Design** - Matches the app's cozy pastel aesthetic with animated hearts and glowing backgrounds
- **Fully Responsive** - Beautiful on mobile, tablet, and desktop
- **Smooth Animations** - Powered by Framer Motion for delightful interactions
- **Waitlist Integration** - Connects to Supabase for beta signup management
- **Optimized Performance** - Built with Next.js 15 and React 19

## 🎨 Design Highlights

- Animated floating hearts matching the app's aesthetic
- Pulsing background gradients with soft blurred blobs
- Feature chips showcasing key app capabilities
- Cute animal showcase (chicken, pig, sheep, horse)
- Smooth form transitions with success/error states
- All lowercase text matching the app's friendly vibe

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

1. **Navigate to the web directory:**
   ```bash
   cd doodleduo-web
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Environment variables are already configured** in `.env.local`

4. **Run the database migration:**

   Deploy the waitlist table migration from `../supabase/migrations/012_waitlist.sql` to your Supabase instance.

5. **Start the development server:**
   ```bash
   npm run dev
   ```

6. **Open your browser:**
   ```
   http://localhost:3000
   ```

## 📦 Build for Production

```bash
npm run build
npm start
```

## 🗂️ Project Structure

```
doodleduo-web/
├── app/
│   ├── layout.tsx        # Root layout with metadata
│   ├── page.tsx          # Landing page with waitlist form
│   └── globals.css       # Global styles
├── lib/
│   └── supabase.ts       # Supabase client and waitlist functions
├── public/
│   └── images/           # Logo and animal images
├── .env.local            # Environment variables (Supabase config)
└── README.md
```

## 🎯 Key Components

### Landing Page
- Hero card with animated logo and floating hearts
- Feature chips grid (realtime board, cozy farm, widget hearts, etc.)
- Waitlist signup form with validation and success states
- Animal showcase section with hover animations
- Fully responsive layout

### Supabase Integration
- `joinWaitlist()` - Adds email to waitlist with duplicate detection
- Tracks referral source and user agent
- Proper error handling for unique constraint violations

## 🎨 Design System

**Colors:**
- Background gradient: `#f7f5f4` → `#ede9f2` → `#e3ebf5`
- Hero card gradient: `#f7f5f4` → `#eee0f1` → `#e0e6f3`
- CTA button gradient: `#e35070` → `#ad75ba`

**Typography:**
- All lowercase for friendly, approachable vibe
- Rounded fonts for cozy aesthetic

**Animations:**
- Floating hearts (continuous loop)
- Pulsing background blobs
- Staggered content reveals
- Hover interactions

## 📱 Responsive Design

- **Mobile**: < 640px (2 feature columns, stacked form)
- **Tablet**: 640px - 768px (2 feature columns)
- **Desktop**: > 768px (3 feature columns, inline form)

## 🚢 Deploy to Vercel

```bash
vercel
```

Or connect your GitHub repository to Vercel for automatic deployments.

## 📊 Waitlist Management

View signups in your Supabase dashboard:

```sql
SELECT email, created_at, referral_source
FROM waitlist
ORDER BY created_at DESC;
```

## 🐛 Troubleshooting

**Images not loading?**
- Verify images exist in `public/images/`
- Clear Next.js cache: `rm -rf .next`

**Supabase connection issues?**
- Check environment variables in `.env.local`
- Ensure RLS policies allow anonymous inserts
- Verify the waitlist table is created

**Build errors?**
- Delete node_modules: `rm -rf node_modules && npm install`
- Check Node.js version: `node --version` (should be 18+)

---

**Made with 💗 for couples who doodle together**

Built with Next.js, React, Tailwind CSS, Framer Motion, and Supabase.
