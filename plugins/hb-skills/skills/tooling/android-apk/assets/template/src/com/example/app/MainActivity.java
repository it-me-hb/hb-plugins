package com.example.app;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;

/**
 * Minimal known-good app, used to prove the toolchain works before any real
 * code exists. If this builds and verifies, later failures are in your app; if
 * it doesn't, the environment is wrong and no amount of app debugging helps.
 *
 * Note the anonymous inner class rather than a lambda — the offline dexer
 * cannot handle invokedynamic. See references/constraints.md.
 */
public class MainActivity extends Activity {

    private int taps = 0;
    private TextView counter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        counter = (TextView) findViewById(R.id.counter);

        findViewById(R.id.button).setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                taps++;
                counter.setText(taps + (taps == 1 ? " tap" : " taps"));
            }
        });
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        out.putInt("taps", taps);
    }

    @Override
    protected void onRestoreInstanceState(Bundle in) {
        super.onRestoreInstanceState(in);
        taps = in.getInt("taps", 0);
        counter.setText(taps + (taps == 1 ? " tap" : " taps"));
    }
}
