# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/newsletter_email
  def newsletter_email
    UserMailer.newsletter_email(
      User.first,
      # rubocop:disable Layout/LineLength
      '# Hi %user_name%,

I have been busy working on [HiFi&thinsp;Log](https://www.hifilog.com) recently and implemented some new features. I hope you find them interesting!

---

**Multiple photos per product**
If you own (or used to own) a product, you can now upload multiple photos of it. They will all be displayed in your profile, giving visitors of it a nice visual overview of your gear.

<img src="https://www.hifilog.com/newsletter/2025-04-06/photos.jpg" alt="" aria-hidden="true">

---

**Statistics and history**
There is now a [statistics page](https://www.hifilog.com/dashboard/statistics) that shows how many products you have bought and sold per year and how many products you own from each brand. Let me know if you are interested in other statistics.

<img src="https://www.hifilog.com/newsletter/2025-04-06/statistics.jpg" alt="" aria-hidden="true">

On the [history page](https://www.hifilog.com/dashboard/history), you get a timeline showing when you bought and sold which product. Of course, you need to add this information to the products, so make sure to fill that out.

<img src="https://www.hifilog.com/newsletter/2025-04-06/history.jpg" alt="" aria-hidden="true">

---

**Bookmark lists**
Until now, you could already bookmark products that interest you. But now you can also create bookmark lists that allow you to categorize them. This can be helpful if, for example, you are looking for a new amplifier for your living room and want to set up a new system for your office at the same time. Simply create a bookmark list for each of them and assign your bookmarks to keep everything nicely organized.

---

By the way, this is the first time I have sent out a newsletter. I will probably do this from time to time with interesting updates, but definitely not too often. If you do not want to receive it, you can of course unsubscribe at any time. Just make sure to check [HiFi&thinsp;Log] (https://www.hifilog.com) regularly, as I am always working on improvements and new features.

Happy listening,
Michael from HiFi&thinsp;Log',
      # rubocop:enable Layout/LineLength
    )
  end
end
