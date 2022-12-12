{ pkgs, lib, config, ... }:
let
  cfg = config.services.lychee;
  src = pkgs.lychee-gallery;
  envConf = cfg.settings;
in
{
  options.services.lychee = {
    enable = lib.mkEnableOption "Whether to enable lychee";
    website = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      example = "www.example.com";
    };
    forceSSL = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to force SSL for the nginx virtual host";
    };
    enableACME = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enableACME for the nginx virtual host";
    };
    upload_max_filesize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Max uploaded file size";
    };
    post_max_size = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Max post request size";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "lychee";
      description = "The user that will operate on mutable files";
    };
    stateDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/lychee";
    };
    settings = lib.mkOption {
      default = {};
      type = lib.types.submodule {
        freeformType = with lib.types; attrsOf str;
        options = {
          DB_DATABASE= lib.mkOption {
            type = lib.types.str;
            default = "${cfg.stateDirectory}/db.sqlite";
          };
          APP_NAME= lib.mkOption {
            type = lib.types.str;
            default = "Lychee";
          };
          APP_ENV = lib.mkOption {
            type = lib.types.str;
            default = "production";
          };
          APP_DEBUG = lib.mkOption {
            type = lib.types.str;
            default = "\"false\"";
          };
          APP_URL = lib.mkOption {
            type = lib.types.str;
            default = "http://localhost";
          };
          DEBUGBAR_ENABLED = lib.mkOption {
            type = lib.types.str;
            default = "\"false\"";
          };
          #DB_OLD_LYCHEE_PREFIX = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          DB_CONNECTION = lib.mkOption {
            type = lib.types.str;
            default = "sqlite";
          };
          #DB_HOST = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #DB_PORT = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #DB_USERNAME = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #DB_PASSWORD = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          DB_LOG_SQL = lib.mkOption {
            type = lib.types.str;
            default = "\"false\"";
          };
          LYCHEE_UPLOADS = lib.mkOption {
            type = lib.types.path;
            default = "${cfg.stateDirectory}/uploads";
          };
          CACHE_DRIVER = lib.mkOption {
            type = lib.types.str;
            default = "file";
          };
          SESSION_DRIVER = lib.mkOption {
            type = lib.types.str;
            default = "file";
          };
          SESSION_LIFETIME = lib.mkOption {
            type = lib.types.str;
            default = "120";
          };
          SECURITY_HEADER_HSTS_ENABLE = lib.mkOption {
            type = lib.types.str;
            default = "\"false\"";
          };
          SESSION_SECURE_COOKIE = lib.mkOption {
            type = lib.types.str;
            default = "\"false\"";
          };
          #REDIS_HOST = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          REDIS_PASSWORD = lib.mkOption {
            type = lib.types.str;
            default = "\"null\"";
          };
          REDIS_PORT = lib.mkOption {
            type = lib.types.str;
            default = "6379";
          };
          MAIL_DRIVER = lib.mkOption {
            type = lib.types.str;
            default = "smtp";
          };
          #MAIL_HOST = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #MAIL_PORT = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #MAIL_USERNAME = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #MAIL_PASSWORD = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #MAIL_ENCRYPTION = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #MAIL_FROM_NAME = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          #MAIL_FROM_ADDRESS = lib.mkOption {
          #  type = lib.types.str;
          #  default = "";
          #};
          TRUSTED_PROXIES = lib.mkOption {
            type = lib.types.str;
            default = "\"null\"";
          };
        };
      };
    };
  };
  config = let srcDirsToBindMount = [
    "app"
    "bootstrap"
    "config"
    "ressources"
    "routes"
    "scripts"
    "vendor"
  ];
  in lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.website} = {
        root = cfg.stateDirectory + "/www/public/";
        forceSSL = lib.mkDefault cfg.forceSSL;
        enableACME = lib.mkDefault cfg.enableACME;
        locations = {
          "^~ /index.php" = {
            fastcgiParams = {
              SCRIPT_FILENAME = "$document_root$fastcgi_script_name";
            };
            extraConfig = ''
              fastcgi_split_path_info ^(.+?\.php)(/.*)$;
              fastcgi_pass unix:${config.services.phpfpm.pools."${cfg.website}".socket};
              fastcgi_index index.php;
              client_max_body_size ${builtins.toString cfg.upload_max_filesize}M;
            '';
          };
          "~ [^/]\.php(/|$)" = {
             return = "403";
          };
          "/uploads/" = {
            alias = cfg.settings.LYCHEE_UPLOADS;
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
    systemd.tmpfiles.rules = let srcDirToTmpFile = dir: "d ${cfg.stateDirectory}/www/${dir} 0750 ${cfg.user} ${config.services.nginx.group}";
    in [
      "d ${cfg.stateDirectory} 0750 ${cfg.user} ${config.services.nginx.group}"
      "d ${cfg.stateDirectory}/www 0750 ${cfg.user} ${config.services.nginx.group}"
      "C ${cfg.stateDirectory}/public - ${cfg.user} ${config.services.nginx.group} - ${src}/public"
      "Z ${cfg.stateDirectory}/public 0750 ${cfg.user} ${config.services.nginx.group} - -"
      "C ${cfg.stateDirectory}/storage - ${cfg.user} ${config.services.nginx.group} - ${src}/storage"
      "Z ${cfg.stateDirectory}/storage 0750 ${cfg.user} ${config.services.nginx.group} - -"
      "C ${cfg.settings.LYCHEE_UPLOADS} - ${cfg.user} ${config.services.nginx.group} - ${src}/public/uploads"
      "Z ${cfg.settings.LYCHEE_UPLOADS} 0750 ${cfg.user} ${config.services.nginx.group} - -"
      "f ${cfg.settings.DB_DATABASE} 0750 ${cfg.user} ${cfg.user}"
    ] ++ (builtins.map srcDirToTmpFile srcDirsToBindMount);
    systemd.mounts = let sourceDirToSystemdMount = dir: {
      before = [ "phpfpm-${cfg.website}.service" ];
      wantedBy = [ "phpfpm-${cfg.website}.service" ];
      what = "${src}/${dir}";
      where = cfg.stateDirectory + "/www/${dir}";
      options = "bind";
    };
    in [{
      before = [ "phpfpm-${cfg.website}.service" ];
      wantedBy = [ "phpfpm-${cfg.website}.service" ];
      what = cfg.stateDirectory + "/public";
      where = cfg.stateDirectory + "/www/public";
      options = "bind";
    }
    {
      before = [ "phpfpm-${cfg.website}.service" ];
      wantedBy = [ "phpfpm-${cfg.website}.service" ];
      what = cfg.stateDirectory + "/storage";
      where = cfg.stateDirectory + "/www/storage";
      options = "bind";
    }] ++ (builtins.map sourceDirToSystemdMount srcDirsToBindMount);
    services.phpfpm.pools.${cfg.website} = {
      user = cfg.user;
      phpPackage = pkgs.php81.withExtensions ({ enabled, all }:
        enabled ++ [ all.imagick all.bcmath all.mbstring all.gd]);
      phpOptions = ''
        upload_max_filesize = ${builtins.toString cfg.upload_max_filesize}M
        post_max_size = ${builtins.toString cfg.post_max_size}M
        '';
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
      };
      phpEnv = {
        "PATH" = lib.makeBinPath [ pkgs.ffmpeg ];
      } // envConf;
    };
    users.users.${cfg.user} = {
      isSystemUser = true;
      home = src;
      group = cfg.user;
    };
    users.groups.${cfg.user} = { };
    #networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}

