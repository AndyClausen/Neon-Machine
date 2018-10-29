---
description: Did something go wrong?
---

# Troubleshooting

Hopefully, this page will help you fix any problem you may have. If your problem is not listed here, create an issue on the GitHub with proper information \(OS, version, etc.\) and a step-by-step guide to reproduce your problem if possible.

{% tabs %}
{% tab title="Windows" %}
### Nothing happens

If nothing happens when you run the program, or a command prompt quickly appears and disappears, then you probably have an irregular installation path to LÖVE, or you don't have the program at all.  
In this case, find out where you installed LÖVE and make sure it matches the path the `[WINDOWS] Run LuaOS.bat` file \(right-click -&gt; edit\). If not, edit the .bat file to match your path.

{% hint style="danger" %}
Do not commit the batch file if you are contributing! Your PR _will_ get rejected.
{% endhint %}
{% endtab %}

{% tab title="Android" %}
## No Game Screen?

Check if you copied or extracted all the files to: _`/storage/lovegame/`_ from _`Neon-Machine-master/`_
{% endtab %}
{% endtabs %}



