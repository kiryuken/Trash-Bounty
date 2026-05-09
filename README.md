
  # AI Bounty Trash System

  This is a code bundle for AI Bounty Trash System. The original project is available at https://www.figma.com/design/Pxz5597dF4Y3I32dcXmPZR/AI-Bounty-Trash-System.

  ## Running the code

  Run `npm i` to install the dependencies.

  Run `npm run dev` to start the development server.

  ## Local backend port policy

  The repo-tracked local backend default is `8080`.

  Native backend startup, Docker startup, and runtime consumers should all assume `http://localhost:8080` unless you explicitly override them.

  Use `BACKEND_PORT=8081` only as a machine-local tunnel override. It is not the general project default.
  