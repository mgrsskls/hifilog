# <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600" width="32" height="32"><path fill="#7a9bb8" d="M300 0C193.69 0 100.3 55.29 47.02 138.69l110.88 64.02a15.41 15.41 0 0 1 5.64 21.05l-2.27 3.93a15.41 15.41 0 0 1-21.05 5.64L29.77 169.56A298.84 298.84 0 0 0 0 300c0 165.69 134.31 300 300 300s300-134.31 300-300S465.69 0 300 0Z"/></svg> HiFi Log

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
  If the list of hi-fi gear you used to own becomes longer and longer, you can simply add them to your list of previously owned products.

## Setup

1. `cp .pre-commit .git/hooks/pre-commit`
2. `touch .env`
3. Add the following to `.env`:

```
CDN_HOST=http://127.0.0.1
CDN_PORT=3000
```

4. `rails db:setup`
