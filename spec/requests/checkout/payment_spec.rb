# frozen_string_literal: true

require "spec_helper"

describe "Checkout payment", :js, type: :system do
  before do
    @product = create(:product, price_cents: 1000)
    Feature.deactivate(:disable_braintree_sales)
  end

  it "shows native, braintree, or no paypal button depending on availability" do
    create(:merchant_account_paypal, user: @product.user, charge_processor_merchant_id: "CJS32DZ7NDN5L", currency: "gbp")
    visit "/l/#{@product.unique_permalink}"
    add_to_cart(@product)
    choose "PayPal"
    if PAYPAL_PARTNER_CLIENT_ID.blank? || PAYPAL_PARTNER_CLIENT_ID.start_with?("test-")
      supports_paypal = page.evaluate_script("JSON.parse(document.querySelector('[data-page]').getAttribute('data-page')).props.checkout.add_products[0].product.supports_paypal")
      expect(supports_paypal).to eq("native")
    else
      expect(page).to have_selector("iframe[title=PayPal]")
    end
    expect(supports_paypal).to eq("native")

    product2 = create(:product, price_cents: 1000)
    visit "/l/#{product2.unique_permalink}"
    add_to_cart(product2)
    choose "PayPal"
    expect(page).to_not have_selector("iframe[title=PayPal]")
    expect(page).to have_button "Pay"

    product3 = create(:product, price_cents: 1000)
    product3.user.update!(disable_paypal_sales: true)
    visit "/l/#{product3.unique_permalink}"
    add_to_cart(product3)
    expect(page).to_not have_field("PayPal", type: "radio")
  end

  it "renders the Stripe Link iframe alongside the card element iframe" do
    visit "/l/#{@product.unique_permalink}"
    add_to_cart(@product)

    within_fieldset "Card information" do
      iframes = all("iframe", minimum: 2, wait: 10)
      expect(iframes.length).to be >= 2
    end
  end

  it "allows auto-filling card details from Stripe Link" do
    visit "/l/#{@product.unique_permalink}"
    add_to_cart(@product)

    fill_in "Email address", with: "gumroad-stripe-link@example.com"
    fill_in "Full name", with: "John Doe"
    fill_in "ZIP code", with: "94107"

    within_fieldset "Card information" do
      within_frame(1) do
        click_on "Autofill with Link"
      end
    end

    within_frame(3) do
      fill_in "Email", with: "gumroad-stripe-link@example.com"
      fill_in "search-codeControllingInput", with: "000000"
      click_on "Continue"
    end

    click_on "Pay"
    expect(page).to have_alert(text: "Your purchase was successful!", visible: :all)

    purchase = Purchase.last
    expect(purchase.successful?).to be(true)
    expect(purchase.card_type).to eq("visa")
    expect(purchase.card_visual).to eq("**** **** **** 4242")
  end

  context "email typo suggestions" do
    before { Feature.activate(:require_email_typo_acknowledgment) }

    it "disables the payment button until typo suggestion is resolved" do
      visit @product.long_url
      add_to_cart(@product)

      expect(page).to have_button "Pay", disabled: false

      fill_in "Email address", with: "hi@gnail.com"
      unfocus
      expect(page).to have_text "Did you mean hi@gmail.com?"
      expect(page).to have_button "Pay", disabled: true

      # Rejecting the typo suggestion does NOT update the field value.
      within_fieldset "Email address" do
        click_on "No"
      end
      expect(page).to have_field("Email address", with: "hi@gnail.com")
      expect(page).to have_button "Pay", disabled: false

      fill_in "Email address", with: "hi@hotnail.com"
      unfocus
      expect(page).to have_text "Did you mean hi@hotmail.com?"
      expect(page).to have_button "Pay", disabled: true

      # Accepting the typo suggestion updates the field value.
      within_fieldset "Email address" do
        click_on "Yes"
      end
      expect(page).to have_field("Email address", with: "hi@hotmail.com")
      expect(page).to have_button "Pay", disabled: false

      # Re-entering a typo that has been acknowledged should not show
      # suggestions again.
      fill_in "Email address", with: "hi@gnail.com"
      unfocus
      expect(page).to_not have_text "Did you mean"
      expect(page).to have_button "Pay", disabled: false
    end

    context "feature flag is off" do
      before { Feature.deactivate(:require_email_typo_acknowledgment) }

      it "does not block the payment button" do
        visit @product.long_url
        add_to_cart(@product)

        expect(page).to have_button "Pay", disabled: false

        fill_in "Email address", with: "hi@gnail.com"
        unfocus
        expect(page).to have_text "Did you mean hi@gmail.com?"
        expect(page).to have_button "Pay", disabled: false
      end
    end
  end
end
