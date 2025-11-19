# DoodleDuo Website Deployment Guide 🚀

Quick guide to deploy your DoodleDuo beta waitlist website.

## Before Deploying

1. **Deploy the database migration first:**
   ```bash
   cd ../supabase
   # Option 1: Using Supabase CLI
   supabase db push

   # Option 2: Copy the SQL from migrations/012_waitlist.sql
   # and run it in the Supabase SQL Editor
   ```

2. **Verify the waitlist table exists:**
   - Open your Supabase project dashboard
   - Go to "Table Editor"
   - Check that the `waitlist` table is present with RLS enabled

## Deployment Options

### Option 1: Vercel (Recommended) ⭐

Vercel is built by the Next.js team and provides the best performance and easiest deployment.

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Deploy:**
   ```bash
   cd doodleduo-web
   vercel
   ```

3. **Follow the prompts:**
   - Link to existing project or create new one
   - Confirm project settings
   - Deploy!

4. **Set up automatic deployments:**
   - Push your code to GitHub
   - Connect your GitHub repository to Vercel
   - Every push to `main` will auto-deploy

**Environment Variables:**
The `.env.local` file is not deployed. Vercel will automatically use your local environment variables for the first deployment. For future deployments:
- Go to your project settings on Vercel
- Add environment variables:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`

### Option 2: Netlify

1. **Install Netlify CLI:**
   ```bash
   npm install -g netlify-cli
   ```

2. **Build and deploy:**
   ```bash
   npm run build
   netlify deploy --prod
   ```

3. **Set environment variables:**
   - Go to Site settings → Environment variables
   - Add the same variables as in `.env.local`

### Option 3: Docker

1. **Create a Dockerfile:**
   ```dockerfile
   FROM node:18-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci --only=production
   COPY . .
   RUN npm run build
   EXPOSE 3000
   CMD ["npm", "start"]
   ```

2. **Build and run:**
   ```bash
   docker build -t doodleduo-web .
   docker run -p 3000:3000 --env-file .env.local doodleduo-web
   ```

### Option 4: Custom Server (VPS/Cloud)

1. **Build the app:**
   ```bash
   npm run build
   ```

2. **Transfer files to your server:**
   - `.next/` folder
   - `public/` folder
   - `node_modules/` folder
   - `package.json`
   - `.env.local` (rename to `.env.production`)

3. **Install PM2 for process management:**
   ```bash
   npm install -g pm2
   pm2 start npm --name "doodleduo-web" -- start
   pm2 save
   pm2 startup
   ```

4. **Set up Nginx reverse proxy:**
   ```nginx
   server {
       listen 80;
       server_name yourdomain.com;

       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

## Post-Deployment Checklist

- [ ] Website loads without errors
- [ ] All images display correctly (logo, animals)
- [ ] Animations work smoothly
- [ ] Form submission works (test with your own email)
- [ ] Success message appears after signup
- [ ] Duplicate email shows proper error message
- [ ] Responsive design works on mobile/tablet/desktop
- [ ] Check Supabase dashboard to confirm email was stored

## Testing the Waitlist

1. **Submit a test email:**
   - Use your own email address
   - Check for success message

2. **Verify in Supabase:**
   ```sql
   SELECT * FROM waitlist ORDER BY created_at DESC LIMIT 5;
   ```

3. **Test duplicate submission:**
   - Try submitting the same email again
   - Should show "already on waitlist" error

4. **Check referral tracking:**
   - Visit from different sources (direct, social media links)
   - Verify `referral_source` is being tracked

## Custom Domain Setup

### Vercel
1. Go to project settings → Domains
2. Add your custom domain
3. Update DNS records as shown
4. SSL certificate is automatic

### Netlify
1. Go to Domain settings → Add custom domain
2. Follow DNS configuration steps
3. Enable HTTPS (automatic)

## Monitoring & Analytics

**Recommended tools:**
- **Vercel Analytics** - Built-in, tracks page views and performance
- **Google Analytics** - Add to `app/layout.tsx`
- **Supabase Dashboard** - Monitor waitlist signups in real-time
- **Sentry** - Error tracking (optional)

## Updating the Website

1. **Make your changes locally**
2. **Test thoroughly:**
   ```bash
   npm run dev  # Test in development
   npm run build # Test production build
   ```
3. **Deploy:**
   - Vercel: `git push` (if auto-deploy enabled) or `vercel --prod`
   - Netlify: `netlify deploy --prod`
   - Manual: Re-run build and transfer files

## Troubleshooting

**"Module not found" errors:**
- Delete `.next` and `node_modules`
- Run `npm install && npm run build`

**Images not showing:**
- Verify images are in `public/images/`
- Check file names match exactly (case-sensitive)

**Form not submitting:**
- Check browser console for errors
- Verify Supabase environment variables
- Check RLS policies in Supabase

**Slow page load:**
- Enable image optimization (automatic in Vercel)
- Check your hosting provider's region
- Consider using a CDN

## Need Help?

- **Next.js Docs:** https://nextjs.org/docs
- **Vercel Support:** https://vercel.com/support
- **Supabase Docs:** https://supabase.com/docs

---

**Ready to launch!** 🚀

Your beautiful DoodleDuo beta waitlist website is ready to collect signups.
