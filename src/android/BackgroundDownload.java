package org.apache.cordova.backgroundDownload;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Timer;

/**
 * Created by lies on 05/09/2017.
 */

public class BackgroundDownload  extends CordovaPlugin {

    private static final long DOWNLOAD_ID_UNDEFINED = -1;
    private static final String TEMP_DOWNLOAD_FILE_EXTENSION = ".temp";
    private static final String LOG_TAG = "BackgroundDownload";
    private JSONArray cookies;

    protected class Download {

        private String filePath;
        private String tempFilePath;
        private String uriString;
        private CallbackContext callbackContext; // The callback context from which we were invoked.
        private CallbackContext callbackContextDownloadStart; // The callback context from which we started file download command.
        private long downloadId = DOWNLOAD_ID_UNDEFINED;
        private DownloadManager.Request request;

        public Download(String uriString, String filePath,
                        CallbackContext callbackContext) {

            Log.d(LOG_TAG, "new Download " + uriString);

            this.setUriString(uriString);
            this.setFilePath(filePath);
            this.setTempFilePath(filePath + TEMP_DOWNLOAD_FILE_EXTENSION);
            this.setCallbackContext(callbackContext);
            this.setCallbackContextDownloadStart(callbackContext);
            this.createRequest();
            this.setDestination();
        }

        private void setDestination() {
            this.request.setDestinationUri(Uri.parse(this.tempFilePath));
        }

        public DownloadManager.Request getRequest() { return this.request; }

        private void createRequest() {
            this.request = new DownloadManager.Request(Uri.parse(this.getUriString()));
            this.request.setTitle("org.apache.cordova.backgroundDownload plugin");
            this.request.setVisibleInDownloadsUi(false);
        }

        private void setCookies(JSONArray cookies) {
            for (int i = 0; i < cookies.length(); i++) {
                try {
                    String cookie = cookies.get(i).toString();
                    request.addRequestHeader("Cookie", cookie);
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }
        }

        public String getFilePath() {
            return filePath;
        }

        public void setFilePath(String filePath) {
            this.filePath = filePath;
        }

        public String getUriString() {
            return uriString;
        }

        public void setUriString(String uriString) {
            this.uriString = uriString;
        }

        public String getTempFilePath() {
            return tempFilePath;
        }

        public void setTempFilePath(String tempFilePath) {
            this.tempFilePath = tempFilePath;
        }

        public CallbackContext getCallbackContext() {
            return callbackContext;
        }

        public void setCallbackContext(CallbackContext callbackContext) {
            this.callbackContext = callbackContext;
        }

        public CallbackContext getCallbackContextDownloadStart() {
            return callbackContextDownloadStart;
        }

        public void setCallbackContextDownloadStart(
                CallbackContext callbackContextDownloadStart) {
            this.callbackContextDownloadStart = callbackContextDownloadStart;
        }

        public long getDownloadId() {
            return downloadId;
        }

        public void setDownloadId(long downloadId) {
            this.downloadId = downloadId;
        }

    }


    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        try {
            if (action.equals("startAsync")) {
                startAsync(args, callbackContext);
                return true;
            }
            if (action.equals("stop")) {
                stop(args, callbackContext);
                return true;
            }
            if (action.equals("setCookies")) {
                setCookies(args, callbackContext);
                return true;
            }
            return false; // invalid action
        } catch (Exception ex) {
            callbackContext.error(ex.getMessage());
        }
        return true;
    }

    private void stopAll(String uri) {
        DownloadManager mgr = (DownloadManager) cordova.getActivity().getSystemService(Context.DOWNLOAD_SERVICE);

        DownloadManager.Query query = new DownloadManager.Query();
        query.setFilterByStatus(DownloadManager.STATUS_PAUSED | DownloadManager.STATUS_PENDING | DownloadManager.STATUS_RUNNING    | DownloadManager.STATUS_SUCCESSFUL);
        Cursor cur = mgr.query(query);
        int idxId = cur.getColumnIndex(DownloadManager.COLUMN_ID);
        int idxUri = cur.getColumnIndex(DownloadManager.COLUMN_URI);
        for (cur.moveToFirst(); !cur.isAfterLast(); cur.moveToNext()) {
            if (uri.equals(cur.getString(idxUri))) {
                mgr.remove(cur.getLong(idxId));
                activDownloads.remove(cur.getLong(idxId));
            }
        }
        cur.close();
    }

    private void pauseAll() {
        DownloadManager mgr = (DownloadManager) cordova.getActivity().getSystemService(Context.DOWNLOAD_SERVICE);
        for (Iterator<Long> it = activDownloads.keySet().iterator(); it.hasNext();) {
            Long id = it.next();
            stoppedDownloads.add(activDownloads.get(id));
            mgr.remove(id);
            activDownloads.remove(id);
        }
    }

    private void resumeAll() {
        Iterator<Download> it = stoppedDownloads.iterator();
        while(it.hasNext()) {
            startDownload(it.next());
            it.remove();
        }
    }

    private void startDownload(final Download download) {

        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                // stop all other downloads
                stopAll(download.getUriString());
                download.setCookies(cookies);

                // make sure file does not exist, in other case DownloadManager will fail
                File targetFile = new File(Uri.parse(download.getTempFilePath()).getPath());
                targetFile.delete();

                DownloadManager mgr = (DownloadManager) cordova.getActivity().getSystemService(Context.DOWNLOAD_SERVICE);
                if (activDownloads.size() == 0) {
                    // required to receive notification when download is completed
                    cordova.getActivity().registerReceiver(receiver, new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));
                }
                download.setDownloadId(mgr.enqueue(download.getRequest()));
                activDownloads.put(download.getDownloadId(), download);
            }
        });

    }

    List<Download> stoppedDownloads = new ArrayList<Download>();
    HashMap<Long, Download> activDownloads = new HashMap<Long, Download>();

    private void startAsync(final JSONArray args, final CallbackContext callbackContext) throws JSONException {

                try {

                    setCookies(args.getJSONArray(2));

                    //create new download
                    Download curDownload = new Download(args.get(0).toString(), args.get(1).toString(), callbackContext);

                    startDownload(curDownload);

                } catch (JSONException e) {
                    e.printStackTrace();
                }

    }
    private void stop(JSONArray args, CallbackContext callbackContext) throws JSONException {

    }

    private void setCookies(JSONArray args, CallbackContext callbackContext) throws JSONException {
        this.setCookies(args);
        // todo: stop and restart all activ
    }

    private void setCookies(JSONArray args) {
        this.cookies = args;
        // todo: stop and restart all activ
    }

    private String getUserFriendlyReason(int reason) {
        String failedReason = String.valueOf(reason);
        switch (reason) {
            case DownloadManager.ERROR_CANNOT_RESUME:
                failedReason = "ERROR_CANNOT_RESUME";
                break;
            case DownloadManager.ERROR_DEVICE_NOT_FOUND:
                failedReason = "ERROR_DEVICE_NOT_FOUND";
                break;
            case DownloadManager.ERROR_FILE_ALREADY_EXISTS:
                failedReason = "ERROR_FILE_ALREADY_EXISTS";
                break;
            case DownloadManager.ERROR_FILE_ERROR:
                failedReason = "ERROR_FILE_ERROR";
                break;
            case DownloadManager.ERROR_HTTP_DATA_ERROR:
                failedReason = "ERROR_HTTP_DATA_ERROR";
                break;
            case DownloadManager.ERROR_INSUFFICIENT_SPACE:
                failedReason = "ERROR_INSUFFICIENT_SPACE";
                break;
            case DownloadManager.ERROR_TOO_MANY_REDIRECTS:
                failedReason = "ERROR_TOO_MANY_REDIRECTS";
                break;
            case DownloadManager.ERROR_UNHANDLED_HTTP_CODE:
                failedReason = "ERROR_UNHANDLED_HTTP_CODE";
                break;
            case DownloadManager.ERROR_UNKNOWN:
                failedReason = "ERROR_UNKNOWN";
                break;
        }

        return failedReason;
    }

    private void cleanup(Download curDownload) {
        DownloadManager mgr = (DownloadManager) cordova.getActivity().getSystemService(Context.DOWNLOAD_SERVICE);
        mgr.remove(curDownload.getDownloadId());
        activDownloads.remove(curDownload.getDownloadId());
    }

    private BroadcastReceiver receiver = new BroadcastReceiver() {
        public void onReceive(final Context context, final Intent intent) {

            cordova.getThreadPool().execute(new Runnable() {
                @Override
                public void run() {
                    Log.d(LOG_TAG, "BroadcastReceiver run");

                    DownloadManager mgr = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);

                    long downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                    DownloadManager.Query query = new DownloadManager.Query();
                    query.setFilterById(downloadId);
                    Cursor cursor = mgr.query(query);
                    int idxStatus = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS);

                    if (cursor.moveToFirst()) {
                        Download curDownload = activDownloads.get(downloadId);

                        if (cursor.moveToFirst()) {
                            int status = cursor.getInt(idxStatus);
                            if (status == DownloadManager.STATUS_SUCCESSFUL) {
                                copyTempFileToActualFile(curDownload);
                            } else {
                                int idxReason = cursor.getColumnIndex(DownloadManager.COLUMN_REASON);
                                int reason = cursor.getInt(idxReason);
                                if (reason == 403) {
                                    curDownload.getCallbackContextDownloadStart().error(getUserFriendlyReason(reason));
                                } else {
                                    curDownload.getCallbackContextDownloadStart().error(getUserFriendlyReason(reason));
                                }
                            }
                        } else {
                            curDownload.getCallbackContextDownloadStart().error("cancelled or terminated");
                        }
                        cleanup(curDownload);
                        cursor.close();
                    }
                }
            });
        }
    };

    public void copyTempFileToActualFile(Download curDownload) {
        File sourceFile = new File(Uri.parse(curDownload.getTempFilePath()).getPath());
        File destFile = new File(Uri.parse(curDownload.getFilePath()).getPath());
        if (sourceFile.renameTo(destFile)) {
            curDownload.getCallbackContextDownloadStart().success();
            Log.d(LOG_TAG, "copyTempFileToActualFile STATUS_SUCCESSFUL");
        } else {
            curDownload.getCallbackContextDownloadStart().error("Cannot copy from temporary path to actual path");
        }
    }

}
