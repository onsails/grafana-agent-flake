{
  description = "A very basic flake";

  outputs = { self, nixpkgs }:
    {
      nixosModule = ./grafana-agent.nix;
    };
}
