package com.algoadtech.braintree;

import android.content.Intent;
import android.util.Log;

import com.braintreepayments.api.BraintreeFragment;
import com.braintreepayments.api.PayPal;
import com.braintreepayments.api.exceptions.InvalidArgumentException;
import com.braintreepayments.api.interfaces.BraintreeCancelListener;
import com.braintreepayments.api.interfaces.BraintreeErrorListener;
import com.braintreepayments.api.interfaces.PaymentMethodNonceCreatedListener;

import com.braintreepayments.api.models.PayPalAccountNonce;
import com.braintreepayments.api.models.PayPalRequest;
import com.braintreepayments.api.models.PaymentMethodNonce;
import com.braintreepayments.api.models.PostalAddress;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

public class BrainTreePayPalPlugin extends CordovaPlugin  implements BraintreeErrorListener, PaymentMethodNonceCreatedListener, BraintreeCancelListener {

    private final String TAG = "BrainTreePayPal";
    private BraintreeFragment mBraintreeFragment = null;
    private CallbackContext callbackContext = null;

    protected void pluginInitialize() {
        Log.v(TAG, "Plugin Initializing");
    }

    @Override
    public synchronized boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {

        if(action.equals("init")) {
            return this.executeInit(args, callbackContext);
        }

        if(mBraintreeFragment == null) {
            callbackContext.error("plugin not initialized");
            return true;
        }

        if(action.equals("showPaymentUI")) {
            String amount = args.getString(0);

            if (amount == null) {
                callbackContext.error("amount is required.");
                return true;
            }

            String currency = args.getString(1);
            if(currency == null) {
                callbackContext.error("currency is required.");
                return true;
            }
            
            this.callbackContext = callbackContext;

            JSONObject shippingAddress = args.getJSONObject(2);

            PayPalRequest request =  new PayPalRequest(amount)
                    .currencyCode(currency)
                    .intent(PayPalRequest.INTENT_AUTHORIZE);

            if(shippingAddress != null) {
                PostalAddress postalAddress = this.getPostalAddress(shippingAddress);
                request.shippingAddressOverride(postalAddress);
            }

            this.cordova.setActivityResultCallback(this);
            PayPal.requestOneTimePayment(mBraintreeFragment, request);

            return true;
        }

        return false;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);
        Log.i(TAG, "Activity result fired");
    }

    private boolean executeInit(JSONArray args, CallbackContext callbackContext) throws JSONException {
        if(this.mBraintreeFragment != null) {
            callbackContext.success();
            return true;
        }

        String authorizationToken = args.getString(0);
        if(authorizationToken == null || authorizationToken.isEmpty()) {
            callbackContext.error("A token is required");
            return true;
        }

        try {

            mBraintreeFragment = BraintreeFragment.newInstance(this.cordova.getActivity(), authorizationToken);
            mBraintreeFragment.addListener(this);

            callbackContext.success();
            return true;
        } catch (InvalidArgumentException e) {
            // There was an issue with your authorization string.
            callbackContext.error("Initialization failed");
        }

        return true;
    }

    @Override
    public synchronized void onError(Exception error) {
        callbackContext.error( error.getMessage());
        callbackContext = null;
        Log.i(TAG, "Brain Tree OnError: " + error.getMessage());
    }

    @Override
    public synchronized void onCancel(int requestCode) {
        Map<String, Object> resultMap = new HashMap<>();
        resultMap.put("userCancelled", true);
        callbackContext.success(new JSONObject(resultMap));
        callbackContext = null;
        Log.i(TAG, "Brain Tree onCancel");
    }

    @Override
    public synchronized void onPaymentMethodNonceCreated(PaymentMethodNonce paymentMethodNonce) {
        Log.i(TAG, "Brain Tree onPaymentMethodNonceCreated");

        if(this.callbackContext == null) {
            Log.i(TAG, "Callback is not present");
            return;
        }

        Log.i(TAG, "Callback Found! Moving on and processing payment result");

        Map<String, Object> result = this.getPaypalNonceResult(paymentMethodNonce);
        callbackContext.success(new JSONObject(result));
        callbackContext = null;
    }

    private Map<String, Object> getPaypalNonceResult(PaymentMethodNonce paymentMethodNonce) {

        Map<String, Object> resultMap = new HashMap<>();

        resultMap.put("nonce", paymentMethodNonce.getNonce());
        resultMap.put("type", paymentMethodNonce.getTypeLabel());
        resultMap.put("localizedDescription", paymentMethodNonce.getDescription());

        // PayPal
        if (paymentMethodNonce instanceof PayPalAccountNonce) {
            PayPalAccountNonce payPalAccountNonce = (PayPalAccountNonce)paymentMethodNonce;

            Map<String, Object> innerMap = new HashMap<>();

            innerMap.put("email", payPalAccountNonce.getEmail());
            innerMap.put("firstName", payPalAccountNonce.getFirstName());
            innerMap.put("lastName", payPalAccountNonce.getLastName());
            innerMap.put("phone", payPalAccountNonce.getPhone());
            innerMap.put("clientMetadataId", payPalAccountNonce.getClientMetadataId());
            innerMap.put("payerId", payPalAccountNonce.getPayerId());

            resultMap.put("payPalAccount", innerMap);
        }

        return resultMap;
    }

    private PostalAddress getPostalAddress(JSONObject addressObject) throws  JSONException {
        PostalAddress postalAddress =  new PostalAddress();

        postalAddress.recipientName( this.getAddressValue(addressObject, "recipientName"));
        postalAddress.streetAddress( this.getAddressValue(addressObject, "streetAddress"));
        postalAddress.extendedAddress( this.getAddressValue(addressObject, "extendedAddress"));
        postalAddress.postalCode( this.getAddressValue(addressObject, "postalCode"));
        postalAddress.region( this.getAddressValue(addressObject, "region"));
        postalAddress.locality( this.getAddressValue(addressObject, "locality"));
        postalAddress.countryCodeAlpha2( this.getAddressValue(addressObject, "countryCodeAlpha2"));

        return postalAddress;
    }

    private String getAddressValue(JSONObject addressObject, String fieldName) throws  JSONException {
        return addressObject.has(fieldName) ? addressObject.getString(fieldName) : "";
    }

}