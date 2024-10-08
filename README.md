# HiFi Log

_HiFi Log_ is a user-driven platform for hifi products and brands.

## Features

- **Browse current and discontinued products**<br>
  If you are considering a new purchase or looking for information about a discontinued product: HiFi Log lists products that are still in production, but also those that have long since been discontinued.
- **Help expanding the database**<br>
  Be part of a community and contribute to expanding our database by adding new products and brands to HiFi Log or updating inaccurate or missing information.
- **Find brands and their products**<br>
  If you are interested in the products of specific brand or want to know which brands offer certain kinds of products, you can search through almost 3000 brands.
- **Create bookmarks and notes**<br>
  Bookmark any product you are interested in to ensure you remember it later. You can also write private notes for any product — wether you own them, have bookmarked them or neither.
- **Build your personal collection**<br>
  You can add existing or your own custom built products to your collection, assign them to different listening setups and upload photos of your own gear to show others what you own.
- **Keep track of products you used to own**<br>
  If the list of hi-fi gear you used to own becomes longer and longer, you can simply add them to your list of previous products. After adding the date of ownership, you will get a history and statistics on your hifi gear.

## Setup

1. `cp .pre-commit .git/hooks/pre-commit`
2. `touch .env`
3. Add the following to `.env`:

```
CDN_HOST=http://127.0.0.1
CDN_PORT=3000
```

4. `rails db:setup`
