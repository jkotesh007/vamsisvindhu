import 'dart:io';

import 'package:apple_sign_in/apple_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:grocery_store/blocs/sign_in_bloc/signin_bloc.dart';
import 'package:grocery_store/config/config.dart';
import 'package:grocery_store/config/paths.dart';
import 'package:grocery_store/pages/home_page.dart';
import 'package:grocery_store/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_credit_card/credit_card_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'verification_screen.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  MaskedTextController mobileNoController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String mobileNo;
  bool inProgress, inProgressApple;
  SigninBloc signinBloc;

  @override
  void initState() {
    super.initState();
    inProgress = false;
    inProgressApple = false;

    mobileNoController = MaskedTextController(mask: '0000000000');
    signinBloc = BlocProvider.of<SigninBloc>(context);

//TODO:Detect if signed up or not while signing in

    signinBloc.listen((state) {
      if (state is SignInWithGoogleInProgress) {
        print('sign in with google in progress');

        setState(() {
          inProgress = true;
        });
      }
      if (state is SigninWithGoogleFailed) {
        //failed
        print('sign in with google failed');
        setState(() {
          inProgress = false;
        });
        showFailedSnakbar('Sign in with Google failed!');
      }
      if (state is SigninWithGoogleCompleted) {
        print('sign in with google completed');
        //proceed

        setState(() {
          inProgress = false;
        });

        if (state.result.isEmpty) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        } else {
          showFailedSnakbar(state.result);
        }
      }
      if (state is CheckIfBlockedInProgress) {
        print('in progress');
      }
      if (state is CheckIfBlockedFailed) {
        //failed
        print('failed to check');
        setState(() {
          inProgress = false;
        });
        showFailedSnakbar('Failed to sign in!');
      }
      if (state is CheckIfBlockedCompleted) {
        setState(() {
          inProgress = false;
        });
        if (state.result.isEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen(
                mobileNo: mobileNo,
                isSigningIn: true,
              ),
            ),
          );
        } else {
          showFailedSnakbar(state.result);
        }
      }
    });
  }

  signInWithApple() async {
    setState(() {
      inProgressApple = true;
    });

    try {
      final result = await AppleSignIn.performRequests([
        AppleIdRequest(
          requestedScopes: [
            Scope.fullName,
            Scope.email,
          ],
        )
      ]);

      // 2. check the result
      switch (result.status) {
        case AuthorizationStatus.authorized:
          final appleIdCredential = result.credential;
          final oAuthProvider = OAuthProvider('apple.com');
          final credential = oAuthProvider.credential(
            idToken: String.fromCharCodes(appleIdCredential.identityToken),
            accessToken:
                String.fromCharCodes(appleIdCredential.authorizationCode),
          );
          final authResult =
              await FirebaseAuth.instance.signInWithCredential(credential);
          // final firebaseUser = authResult.user;
          // final displayName =
          //     '${appleIdCredential.fullName.givenName} ${appleIdCredential.fullName.familyName}';
          // await firebaseUser.updateProfile(displayName: displayName);

          User user = FirebaseAuth.instance.currentUser;

          DocumentSnapshot snapshot = await FirebaseFirestore.instance
              .collection(Paths.usersPath)
              .doc(user.uid)
              .get();

          if (snapshot.exists) {
            if (snapshot.data()['isBlocked']) {
              await FirebaseAuth.instance.signOut();
              setState(() {
                inProgressApple = false;
              });
              return showFailedSnakbar('Your account has been blocked');
            }
          } else {
            await FirebaseAuth.instance.signOut();
            setState(() {
              inProgressApple = false;
            });
            return showFailedSnakbar('Account does not exist');
          }

          // return firebaseUser;
          print('SIGNED IN');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
          break;

        case AuthorizationStatus.error:
          throw PlatformException(
            code: 'ERROR_AUTHORIZATION_DENIED',
            message: result.error.toString(),
          );

        case AuthorizationStatus.cancelled:
          throw PlatformException(
            code: 'ERROR_ABORTED_BY_USER',
            message: 'Sign in aborted by user',
          );
        default:
          throw UnimplementedError();
      }

      // final AuthCredential credential1 = OAuthProvider('apple.com').credential(
      //   accessToken: credential.authorizationCode,
      //   idToken: credential.identityToken,
      // );

      // await FirebaseAuth.instance.signInWithCredential(credential1);

      // User user = FirebaseAuth.instance.currentUser;

      // DocumentSnapshot snapshot = await FirebaseFirestore.instance
      //     .collection(Paths.usersPath)
      //     .doc(user.uid)
      //     .get();

      // if (snapshot.exists) {
      //   if (snapshot.data()['isBlocked']) {
      //     await FirebaseAuth.instance.signOut();
      //     return showFailedSnakbar('Your account has been blocked');
      //   }
      // } else {
      //   await FirebaseAuth.instance.signOut();
      //   return showFailedSnakbar('Account does not exist');
      // }

      //TODO: continue

    } catch (e) {
      print(e);
      setState(() {
        inProgressApple = false;
      });
      showFailedSnakbar('Sign in with Apple failed!');
    }
  }

  void showFailedSnakbar(String s) {
    SnackBar snackbar = SnackBar(
      content: Text(
        s,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      duration: Duration(seconds: 3),
      backgroundColor: Colors.red,
      action: SnackBarAction(
          label: 'OK', textColor: Colors.white, onPressed: () {}),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      key: _scaffoldKey,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              height: 200.0,
              width: size.width,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).primaryColorDark,
                    Theme.of(context).primaryColor,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(30.0),
                  bottomLeft: Radius.circular(30.0),
                ),
              ),
              child: SvgPicture.asset(
                'assets/banners/signin_top.svg',
                fit: BoxFit.fitWidth,
              ),
            ),
            Container(
              height: size.height - 200.0,
              width: size.width,
              padding:
                  const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                children: <Widget>[
                  SizedBox(
                    height: 8.0,
                  ),
                  Text(
                    'Welcome',
                    style: GoogleFonts.poppins(
                      color: Colors.black.withOpacity(0.85),
                      fontSize: 20.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(
                    height: 8.0,
                  ),
                  Text(
                    'Sign in and get all the groceries at your doorstep',
                    style: GoogleFonts.poppins(
                      color: Colors.black.withOpacity(0.7),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(
                    height: 20.0,
                  ),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      // controller: mobileNoController,
                      textAlignVertical: TextAlignVertical.center,
                      validator: (String val) {
                        if (val.isEmpty) {
                          return 'Mobile No. is required';
                        }
                        // else if (val.length != 10) {
                        //   return 'Mobile No. is invalid';
                        // }
                        return null;
                      },
                      onSaved: (val) {
                        mobileNo = val;
                      },
                      enableInteractiveSelection: false,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(0),
                        helperStyle: GoogleFonts.poppins(
                          color: Colors.black.withOpacity(0.65),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        prefixText: '${Config().countryMobileNoPrefix} ',
                        prefixStyle: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                        ),
                        errorStyle: GoogleFonts.poppins(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        prefixIcon: Icon(
                          Icons.phone,
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 50.0,
                        ),
                        labelText: 'Mobile no.',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 20.0,
                  ),
                  buildSignInButton(size, context),
                  SizedBox(
                    height: 20.0,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
                    child: Center(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Divider(
                              color: Colors.black54,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Text(
                              'OR',
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 15.0,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 20.0,
                  ),
                  buildGoogleSignInButton(size),
                  Platform.isIOS ? buildAppleSignInButton(size) : SizedBox(),
                  SizedBox(
                    height: 20.0,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Text(
                        'Don\'t have an account?',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      FlatButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/sign_up');
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSignInButton(Size size, BuildContext context) {
    return Center(
      child: Container(
        width: size.width,
        height: 48.0,
        child: FlatButton(
          onPressed: () {
            signInWithMobile();
          },
          color: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Text(
            'Sign In',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildGoogleSignInButton(Size size) {
    return Center(
      child: inProgress
          ? CircularProgressIndicator()
          : Container(
              width: size.width,
              height: 48.0,
              child: FlatButton(
                onPressed: () {
                  signinBloc.add(SignInWithGoogle());
                  setState(() {
                    inProgress = true;
                  });
                },
                color: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      FontAwesomeIcons.google,
                      color: Colors.white,
                      size: 20.0,
                    ),
                    SizedBox(
                      width: 12.0,
                    ),
                    Text(
                      'Sign in with Google',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget buildAppleSignInButton(Size size) {
    return Column(
      children: [
        SizedBox(
          height: 15,
        ),
        Center(
          child: inProgressApple
              ? CircularProgressIndicator()
              : Container(
                  width: size.width,
                  height: 48.0,
                  child: FlatButton(
                    onPressed: () async {
                      // signinBloc.add(SignInWithGoogle());

                      signInWithApple();
                    },
                    color: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          FontAwesomeIcons.apple,
                          color: Colors.white,
                          size: 24.0,
                        ),
                        SizedBox(
                          width: 12.0,
                        ),
                        Text(
                          'Sign in with Apple',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void signInWithMobile() {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      mobileNo = '${Config().countryMobileNoPrefix}$mobileNo';
      signinBloc.add(CheckIfBlocked(mobileNo));
      inProgress = true;
    }
  }
}
