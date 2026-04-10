import { betterAuth } from "better-auth";
import { prismaAdapter } from "better-auth/adapters/prisma";
import { PrismaClient } from "../generated/prisma";
import { nextCookies } from "better-auth/next-js";

const prisma = new PrismaClient();
const isSelfHosted = ["1", "true", "yes"].includes(
  (process.env.NEXT_PUBLIC_SELF_HOST ?? "").toLowerCase()
);
const disableSignUp = ["1", "true", "yes"].includes(
  (process.env.DISABLE_SIGN_UP ?? "").toLowerCase()
);

function toOrigin(value?: string) {
  if (!value) {
    return null;
  }

  try {
    return new URL(value).origin;
  } catch {
    return null;
  }
}

const trustedOrigins = Array.from(
  new Set(
    [
      toOrigin(process.env.NEXT_PUBLIC_APP_URL),
      toOrigin(process.env.BETTER_AUTH_URL),
      "http://localhost:3000",
      "http://sp.localhost:3000",
    ].filter((origin): origin is string => Boolean(origin))
  )
);

export const auth = betterAuth({
  database: prismaAdapter(prisma, {
    provider: "postgresql",
  }),
  user: {
    additionalFields: {
      is_admin: {
        type: "boolean",
        input: false,
      },
    },
  },
  trustedOrigins,
  emailAndPassword: {
    enabled: true,
    disableSignUp,
  },
  databaseHooks: {
    user: {
      create: {
        before: async (user) => {
          if (isSelfHosted) {
            const count = await prisma.user.count();
            if (count > 0) {
              throw new Error("Sign-up is disabled: this is a single-user self-hosted instance.");
            }
          }
          return { data: user };
        },
      },
    },
  },
  plugins: [
    nextCookies(), // Enable Next.js cookie handling
  ],
});

export type Session = typeof auth.$Infer.Session;
