# Vercel Deployment Guide 🚀

## Quick Deploy

You're currently in the `doodleduo-web` directory. Here's what to do:

### 1. Deploy to Vercel

```bash
vercel
```

### 2. Follow the prompts:

- **Set up and deploy?** → Yes
- **Which scope?** → Choose your account (or create one)
- **Link to existing project?** → No
- **What's your project's name?** → doodleduo-web (or press Enter to accept)
- **In which directory is your code located?** → ./ (press Enter)
- **Want to modify settings?** → No (press Enter)

### 3. Wait for deployment

Vercel will:
- Build your Next.js app
- Deploy it to a production URL
- Give you a live URL like: `https://doodleduo-web-xyz.vercel.app`

### 4. Set up environment variables

After first deployment:

```bash
vercel env add NEXT_PUBLIC_SUPABASE_URL
# Paste: https://reevrasmalgiftakwsao.supabase.co

vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
# Paste your anon key from .env.local
```

Then redeploy:
```bash
vercel --prod
```

## Alternative: Deploy via Vercel Dashboard

1. Go to https://vercel.com/new
2. Import your GitHub repo: `tonicoded/doodleduo`
3. Select the `doodleduo-web` directory as root
4. Add environment variables in settings
5. Deploy!

## After Deployment

- Your site will be live at: `https://doodleduo-web.vercel.app`
- Every push to `main` will auto-deploy
- Preview deployments for pull requests

## Custom Domain (Optional)

1. Go to project settings → Domains
2. Add your domain (e.g., `doodleduo.com`)
3. Update DNS records as shown
4. SSL is automatic!

## Troubleshooting

**Build fails?**
```bash
# Test locally first:
npm run build
```

**Environment variables not working?**
- Check they're set for "Production" environment
- Redeploy after adding them

**Need help?**
- Vercel docs: https://vercel.com/docs
- Support: https://vercel.com/support

---

**Ready?** Just run: `vercel`
