# User activity

This document describes the activity feed of users. It uses Simplified Technical English
(ASD-STE100).

## 1. Model

A **`UserActivity`** row records a verb, the time, the affected catalog or social item, and enough
metadata to show a feed entry without a second query for the item.

## 2. Write path

Model callbacks send the changes to **`UserActivities::Recorder`**. The helper **`PossessionSync`**
aligns the verbs that are related to ownership.

The application records activity for:

- Collection changes (current and previous).
- Custom products.
- Setups: created, made public, made private.
- Possessions added to or removed from a setup.
- Event attendance.
- Profile image changes. A purge of a possession or profile image can also make an activity row.
- New follows.

Some verbs are only for auditing. The public feeds do not show them. Some verbs show only on the
dashboard of the owner, never on a public profile.

## 3. Read path

**`UserActivityTimeline`** builds the feed rows for the public overview and the dashboard of the
owner.

- The dashboard feed is based on follows. It merges the activities of the owner with the activities
  of followed users and shows the actor on each row. Hidden profiles are not included.
- The dashboard feed also shows the new entries of followed brands (see
  [brand-follows.md](brand-follows.md)).
- A separate feed page paginates the same timeline in the database.

The timeline applies these rules to the chronological order:

- It obeys the privacy of setups.
- It removes an entry when a later event replaces it.
- It groups a sequence of similar items.

## 4. Backfill

**`UserActivities::Backfill`** can make activities again from existing possessions, setups, RSVPs
and attachments, where the historical data allows it.
