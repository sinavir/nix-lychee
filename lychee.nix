{ pkgs, lib, config, ... }:
let
  cfg = config.lychee;
  src = pkgs.lychee-gallery;
in
{
  options.lychee = {
    enable = "";
    website = "";
    settings = {
      upload_max_filesize = "";
      post_max_size = "";
      user = "";
    };
  };
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.website} = {
        root = src;
        forceSSL = lib.mkDefault cfg.forceSSL;
        enableACME = lib.mkDefault cfg.enableACME;
        locations = {
          "^~ /index.php" = {
            fastcgiParams = {
              SCRIPT_FILENAME = "$document_root$fastcgi_script_name";
            };
            extraConfig = ''
              fastcgi_split_path_info ^(.+?\.php)(/.*)$;
              fastcgi_pass unix:${cfg.services.phpfpm.pools."${config.website}".socket};
              fastcgi_index index.php;
              client_max_body_size ${cfg.settings.upload_max_filesize}M;
            '';
          };
          "~ [^/]\.php(/|$)" = {
             return = "403";
          };
        };
        extraConfig = ''
          index index.php;
          if (!-e $request_filename)
          {
              rewrite ^/(.*)$ /index.php?/$1 last;
              break;
          }
        '';
      };
    };
    services.phpfpm.pools.${cfg.website} = {
      user = cfg.settings.user;
      phpPackage = pkgs.php81.withExtensions ({ enabled, all }:
        enabled ++ [ all.imagick all.bcmath all.mbstring all.gd]);
      phpOptions = ''
        upload_max_filesize = ${cfg.settings.upload_max_filesize}M
        post_max_size = ${cfg.settings.post_max_size}M
        '';
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
        "listen.owner" = cfg.services.nginx.user;
        "listen.group" = cfg.services.nginx.group;
      };
      phpEnv."PATH" = lib.makeBinPath [ pkgs.ffmpeg ];
    };
    users.users.${cfg.settings.user} = {
      isSystemUser = true;
      home = src;
      group = cfg.settings.user;
    };
    users.groups.${cfg.settings.user} = { };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
