package org.luani.client;
import java.lang.reflect.Method;
public final class SupportPolicyTest {
 public static void main(String[] args) throws Exception {
  Method policy;
  try { policy=WebsitePolicy.class.getMethod("isSupportMail",String.class); }
  catch (NoSuchMethodException e) { throw new AssertionError("Support/deletion mail links need a strict recipient policy, not a general intent bridge"); }
  String[] values={"mailto:help@luani.fyi",null,"mailto:attacker@example.com","mailto:help@luani.fyi?cc=attacker@example.com","mailto:help@luani.fyi%0d%0aBcc:attacker@example.com","intent://help@luani.fyi","mailto:help@luani.fyi,attacker@example.com"};
  for(int i=0;i<values.length;i++) {
   boolean actual=(Boolean)policy.invoke(null,values[i]);
   if(actual!=(i==0))throw new AssertionError("Support URL boundary failed at case "+i);
  }
  System.out.println("Support URL policy checks passed: "+values.length);
 }
}
