# PSMF Planner

A polished web app for tracking Protein-Sparing Modified Fast days during a body recomposition cut. Two PSMF days per week, five maintenance days. Drag meals into slots, watch macros fill, build custom meals, track your streak. Built as a static GitHub Pages site backed by Supabase for authentication and persistence.

## What you need

You need a GitHub account, a Supabase account (the free tier is more than sufficient — sign up at supabase.com), and roughly fifteen minutes for first-time setup. After that, day-to-day use requires nothing but a browser.

## Architecture

The shape of this app is worth understanding before you set it up, because the security model depends on it.

GitHub Pages serves the static HTML, CSS, and JavaScript directly from your repository to anyone who visits the URL. Crucially, GitHub Pages does not run any server-side code on your behalf — there is no Node backend, no PHP, no database connection coming from the GitHub side. All the dynamic behavior happens in the visitor's browser, including all communication with the database.

That communication goes directly from the browser to Supabase, which acts as your authentication provider and your database. The browser holds a session token after sign-in and includes it on every request to Supabase. Supabase verifies the token, looks up which user the request is coming from, and then enforces Row Level Security policies that ensure each user can only read and write their own rows. This is the security model: your JavaScript can be public, the anon key can be public, and the data is still safe — because the database itself refuses to return another user's rows regardless of how cleverly the query is crafted.

So three actors, communicating in two channels: GitHub Pages → browser (downloading the app), and browser → Supabase (auth and data).

## Setup

### Step 1: Create a Supabase project

Go to https://supabase.com, sign up if you haven't already, and click "New project". Pick a region close to where you'll be using the app (Europe West if you're in the UK), and generate a strong database password — Supabase will display it once for you to write down somewhere safe. After clicking "Create new project", wait about two minutes for the project to provision. Once it's ready, the dashboard for your project will load automatically.

### Step 2: Run the schema migration

In the left sidebar of your Supabase project, click "SQL Editor", then "New query". Open `schema.sql` from this repo, copy its entire contents, paste them into the SQL editor, and click "Run". You should see a success message at the bottom indicating that statements completed without errors. This single migration creates three tables (`meals`, `day_logs`, `user_state`), a trigger that automatically creates a state row for every new user account, and the Row Level Security policies that protect every user's data from every other user.

### Step 3: Collect your project credentials

In the Supabase sidebar, go to "Project Settings" (the gear icon at the bottom), then "API". You'll see two values you need to copy. The first is the **Project URL**, which looks like `https://abcdefghijklmnop.supabase.co`. The second is the **anon public key**, which is a long JWT-format string starting with `eyJ...`. Both of these are safe to include in client-side code, because, as explained above, the real security is enforced by the RLS policies you just installed, not by hiding these credentials.

### Step 4 (optional but recommended for personal use): disable email confirmation

By default, Supabase sends a confirmation email to every new signup, and the user can't log in until they click the link. For a personal tracker that you might be the only user of, this is unnecessary friction. In the Supabase sidebar, go to "Authentication" → "Providers" → "Email", and toggle off "Confirm email". You can always turn it back on later if you decide to share the app with others.

### Step 5: Configure index.html

Open `index.html` in your text editor and search for `SUPABASE_CONFIG`. You'll find a block near the top of the `<script>` section that looks like this:

```js
const SUPABASE_CONFIG = {
  url:     'https://YOUR-PROJECT-ID.supabase.co',
  anonKey: 'YOUR-ANON-KEY-HERE'
};
```

Replace the placeholder values with the URL and anon key you copied in Step 3, save the file, and you're done editing.

### Step 6: Deploy to GitHub Pages

Create a new GitHub repository (any name works; `psmf-tracker` is a sensible default). Push the three files — `index.html`, `schema.sql`, and `README.md` — to the `main` branch. Then in the repository's "Settings" tab, scroll to "Pages" in the left sidebar. Under "Build and deployment", set "Source" to "Deploy from a branch", set "Branch" to `main` and folder to `/ (root)`, and click "Save". Within a minute or two, GitHub will deploy your site and display the URL at the top of the same page. It will be of the form `https://YOUR-USERNAME.github.io/REPO-NAME/`.

### Step 7: Sign up and use

Visit your new URL, click "Create account", enter an email and password (minimum six characters), and you're in. Your data persists across sessions and devices automatically — log in from your phone with the same credentials, and you'll see the same plans and meal library you created on your laptop.

## What the app does

The app shows you a single PSMF day at a time — Thursday or Sunday, toggled at the top of the screen. Each day has five meal slots in a recommended order: post-walk breakfast around 9:30, lunch around 1pm, a mid-afternoon snack around 4:30, dinner around 7:30, and a pre-bed casein meal around 10pm. The library on the right contains a starter set of fifteen meals drawn from three meal-plan templates plus a few extras. Drag any meal from the library into any slot, and the macro rings at the top of the screen update in real time. A small particle burst fires from each successful drop.

The four macro rings track different things: calorie target is a window (the ring fills toward 1,250 and turns green when you enter the 1,000–1,250 band), protein is a floor (the ring fills toward 150 grams and turns green when met), and fat and carbs are caps (the rings turn red if you exceed 30 grams of either). When all four macros are in their target ranges and at least four slots are filled, the "Log day" button activates. Clicking it increments your streak counter, triggers a celebration overlay with confetti, and then resets the day so you can plan the next one.

Custom meals are built via the "+ Build meal" button. You pick ingredients from a catalog of twenty-nine common PSMF-relevant foods, set grams for each one (defaults are sensible starting points), watch the macro totals update live, name the meal, choose a category, and save. Custom meals appear in the library with a small CUSTOM badge and can be deleted via a hover-revealed button.

A fish oil toggle in the footer accounts for the ~10 grams of fat and ~90 kcal you don't eat as a meal but should still count against your daily budget. Toggle it on once you've taken your capsules and those numbers fold into the totals automatically.

## Optional: enable Google or GitHub login

Email and password works without any additional configuration, which is why it's the default. If you'd rather sign in with Google or GitHub, the upgrade path is straightforward. In Supabase, go to "Authentication" → "Providers", and toggle on whichever provider you want. Each requires registering an OAuth application with that provider (Google: cloud.google.com → APIs → Credentials; GitHub: github.com → Settings → Developer settings → OAuth Apps) and pasting the resulting client ID and secret back into Supabase. Once that's done, you can add a button to the auth screen that calls:

```js
await sb.auth.signInWithOAuth({ provider: 'google' });
```

The rest of the app needs no changes — `currentUser` will be populated identically whether the session came from email/password or OAuth.

## Free tier limits and project pausing

Supabase's free tier gives you 500 MB of database storage, 1 GB of file storage, and 50,000 monthly active users. For a personal tracker, these limits are essentially unreachable — even years of daily use will not approach them. There is one operational note worth understanding: free Supabase projects automatically pause after seven consecutive days of inactivity, and the first request after a pause takes a few extra seconds while the project wakes up. Since logging in counts as activity, if you use the tracker more than once a week you will never encounter this. If you take a vacation and come back to a paused project, the first sign-in attempt may feel slow, but no data is lost.

## Data ownership and exit options

Everything you put into this app lives in your Supabase project under your account. You can export it at any time using the Supabase dashboard: under "Database" → "Tables", click any table and use the "Export" button to download a CSV. For a complete backup, the SQL Editor lets you run `SELECT * FROM meals;`, `SELECT * FROM day_logs;`, and `SELECT * FROM user_state;` and save the results. If you ever decide to host this elsewhere — your own server, a different BaaS provider, an SQLite file — your data comes with you. The source code is yours too; the schema is straightforward enough that porting to a different backend is a weekend project, not a months-long migration.

## What's deliberately not included

This is a focused v1. Several reasonable extensions were considered but left out to keep the surface area small and the polish high. Medium-day and high-day templates are not included; this app covers only the two PSMF days of the weekly protocol. A long-term history view showing which days you logged across previous weeks is not built — the `day_logs` table currently overwrites previous entries when you reset a day, rather than archiving them. Realtime sync across browser tabs is not enabled, so if you make a change on your phone and then look at your laptop without refreshing, the laptop will show stale data. Body weight tracking, photo logging, and coaching nudges (such as warning when one slot dominates the day's protein) are not present. If any of these would be useful, the existing data model supports most of them with modest schema additions.

## Troubleshooting

If you see "Configuration required" when you first visit the page, your `SUPABASE_CONFIG` values in `index.html` still contain the placeholder text. Re-check Step 5.

If sign-in fails with "Invalid login credentials", either the email-password combination is wrong, or email confirmation is enabled and you haven't clicked the confirmation link yet. Check your inbox (and spam folder) for a Supabase email, or follow Step 4 to disable confirmation.

If signup fails with "Email rate limit exceeded", Supabase's free tier rate-limits the auth endpoint to prevent abuse. Wait a minute and try again, or disable email confirmation as in Step 4 (confirmed-by-default signups use a different rate limit pool).

If meals seem to save but disappear on refresh, open your browser's developer console (F12, then the Console tab) and look at errors there. The most common cause is that `schema.sql` wasn't run successfully — you'll see "relation does not exist" or "permission denied" errors. Re-run the migration.

If you want to wipe everything and start over, in Supabase's SQL Editor run `TRUNCATE meals, day_logs, user_state RESTART IDENTITY CASCADE;`. This deletes all data for all users while preserving the schema. To delete users too, go to "Authentication" → "Users" and delete them manually, or run `DELETE FROM auth.users;` in the SQL editor.

If something weirder is happening and you can't tell what, open the browser console and copy the full error message — it almost always identifies the problem precisely. Supabase errors include both a human-readable `message` and a structured error code that's straightforward to look up in the Supabase docs.
