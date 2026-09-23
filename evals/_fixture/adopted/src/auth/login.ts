export async function login(email: string, password: string) {
  const usr = await db.users.findByEmail(decodeURIComponent(email));
  if (!usr || !(await verify(password, usr.hash))) throw new HttpError(401);
  return createSession(usr.id);
}
