# server-plugin-disk
Send alerts when the disk is about to get full

        git clone git@github.com:DDNetPP/server myserver
        cd myserver/lib
        mkdir -p plugins && cd plugins
        git clone git@github.com:DDNetPP/client-plugin-disk

And then in your ``server.cnf`` put the map you want to search for

        # if one of your drives is more than 80% full throw an alert
        pl_disk_max_usage=80
        # send alert to this webhook
        pl_disk_discord_webhook_url=https://discord.com/api/webhooks/xxx/xxx
