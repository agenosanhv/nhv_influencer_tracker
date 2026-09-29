# Campaign Tracker

A board, calendar and table view for influencer campaigns, with email-and-password sign-in and three roles: Admin, Employee and Viewer.

The page is hosted free on **GitHub Pages**. Accounts, passwords and data live in **Supabase**, a hosted database with a built-in sign-in service (free tier is enough for a team). Passwords are handled by Supabase, never stored in the page, and the role rules are enforced by the database itself, so they can't be bypassed from the browser.

Setup takes about 20 minutes.

## 1. Create the Supabase project

1. Sign up at supabase.com and create a new project. Save the database password it asks for somewhere safe.
2. Open **SQL Editor**, paste the whole of `supabase-setup.sql`, and click **Run**.
3. Go to **Authentication → Sign In / Providers** and turn **off** "Allow new users to sign up". This way only people you invite can get in.
4. Go to **Project Settings → API** and copy two values: the **Project URL** and the **anon public** key.

## 2. Put the page on GitHub

1. Open `index.html` and paste those two values near the top of the script:
   ```js
   const SUPABASE_URL      = "https://abcd1234.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...";
   ```
   The anon key is designed to be public. Never paste the **service_role** key into the page.
2. Create a GitHub repository and upload `index.html`.
3. In the repository, go to **Settings → Pages**, set the source to your main branch, and save. After a minute you'll get a web address like `https://yourname.github.io/campaign-tracker/`.

## 3. Connect the two

In Supabase, go to **Authentication → URL Configuration**:

- Set **Site URL** to your GitHub Pages address.
- Add the same address under **Redirect URLs**.

This makes invite and password-reset emails send people back to your tracker.

## 4. Invite your team

1. In Supabase, go to **Authentication → Users → Invite user** and enter each colleague's email, including Adrian's and your own.
2. Each person gets an email, clicks the link, and lands on the tracker to set their name and password.
3. Everyone starts as a **Viewer**.

## 5. Make Adrian the admin and hide your name

Once Adrian has accepted his invite, run these in the **SQL Editor** (with the real email addresses):

```sql
update public.profiles set role = 'admin' where email = 'adrian@yourcompany.com';
update public.profiles set hide_name = true where email = 'you@yourcompany.com';
```

From then on, Adrian manages everyone else from the **Team** tab in the tracker: he can make people Employees or Admins and choose whose names show on edits. With `hide_name` on, your edits never show your name or initials to anyone.

## Who can do what

| Role | View | Add and edit | Move cards | Delete | Manage team |
|---|---|---|---|---|---|
| Admin | ✓ | ✓ | ✓ | ✓ | ✓ |
| Employee | ✓ | ✓ | ✓ | | |
| Viewer | ✓ | | | | |

## Good to know

- **Adding people later:** always invite them in Supabase first, then set their role in the Team tab.
- **Forgot password:** the sign-in screen has a "Forgot password?" link that emails a reset link.
- **Emails:** Supabase's built-in email service is limited to a few emails per hour, which is fine for invites to a small team. For more, connect your own email provider under **Authentication → Emails → SMTP settings**.
- **Free tier:** Supabase pauses free projects after a week with no activity. Opening the dashboard wakes it back up, and normal daily use keeps it running.
- **Changing channels:** edit the `CHANNELS` list near the top of the script in `index.html`.
