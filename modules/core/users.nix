# Primary user account. Set the password once with `passwd valer`.
{ ... }:
{
  users.users."valer" = {
    isNormalUser = true;
    description = "Valerio";
    extraGroups = [ "networkmanager" "wheel" ];
  };
}
